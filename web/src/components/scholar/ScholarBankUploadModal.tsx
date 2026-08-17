import React, { useState } from 'react';
import { supabase } from '@/services/supabaseClient';
import { extractBankDetailsFromImage, convertPdfDataUrlToImage, type ExtractedBankDetails } from '@/services/aiExtractionService';

interface ScholarBankUploadModalProps {
  scholarId: string;
  scholarName: string;
  isOpen: boolean;
  onClose: () => void;
  onSuccess: (accountData: any) => void;
  requiredBankPolicy?: 'specific_bank' | 'any_bank' | 'provider_issued';
  requiredBankName?: string;
}

const PH_BANKS = [
  'Landbank of the Philippines',
  'BDO Unibank',
  'BPI (Bank of the Philippine Islands)',
  'UnionBank of the Philippines',
  'Metrobank',
  'SeaBank Philippines',
  'RCBC',
  'Security Bank',
  'Philippine National Bank (PNB)',
  'Development Bank of the Philippines (DBP)',
  'Maya Bank',
  'GoTyme Bank',
  'Other Bank',
];

export function matchPhilippineBank(rawBankName: string): string {
  if (!rawBankName) return 'Landbank of the Philippines';
  const clean = rawBankName.toLowerCase().replace(/[^a-z0-9]/g, '');

  if (clean.includes('unionbank') || clean.includes('union')) {
    return 'UnionBank of the Philippines';
  }
  if (clean.includes('landbank') || clean.includes('lbp') || clean.includes('land')) {
    return 'Landbank of the Philippines';
  }
  if (clean.includes('bdo') || clean.includes('bancodeoro')) {
    return 'BDO Unibank';
  }
  if (clean.includes('bpi') || clean.includes('philippineislands')) {
    return 'BPI (Bank of the Philippine Islands)';
  }
  if (clean.includes('metrobank') || clean.includes('metropolitan')) {
    return 'Metrobank';
  }
  if (clean.includes('seabank')) {
    return 'SeaBank Philippines';
  }
  if (clean.includes('rcbc') || clean.includes('rizal')) {
    return 'RCBC';
  }
  if (clean.includes('securitybank') || clean.includes('security')) {
    return 'Security Bank';
  }
  if (clean.includes('pnb') || clean.includes('philippinenational')) {
    return 'Philippine National Bank (PNB)';
  }
  if (clean.includes('dbp') || clean.includes('developmentbank')) {
    return 'Development Bank of the Philippines (DBP)';
  }
  if (clean.includes('maya')) {
    return 'Maya Bank';
  }
  if (clean.includes('gotyme')) {
    return 'GoTyme Bank';
  }

  const found = PH_BANKS.find(
    (b) =>
      b.toLowerCase().includes(rawBankName.toLowerCase()) ||
      rawBankName.toLowerCase().includes(b.toLowerCase())
  );
  if (found) return found;

  return 'Other Bank';
}

export const ScholarBankUploadModal: React.FC<ScholarBankUploadModalProps> = ({
  scholarId,
  scholarName,
  isOpen,
  onClose,
  onSuccess,
  requiredBankPolicy = 'any_bank',
  requiredBankName,
}) => {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [isScanning, setIsScanning] = useState(false);
  const [scanStatus, setScanStatus] = useState<string>('');
  const [isSaving, setIsSaving] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Form Fields
  const [bankName, setBankName] = useState<string>(
    requiredBankPolicy === 'specific_bank' && requiredBankName
      ? requiredBankName
      : 'Landbank of the Philippines'
  );
  const [accountName, setAccountName] = useState<string>(scholarName || '');
  const [accountNumber, setAccountNumber] = useState<string>('');
  const [extractedInfo, setExtractedInfo] = useState<ExtractedBankDetails | null>(null);

  if (!isOpen) return null;

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setSelectedFile(file);
    setErrorMessage(null);
    setExtractedInfo(null);

    // Create preview and process
    const reader = new FileReader();
    reader.onload = async () => {
      let dataUrl = reader.result as string;
      
      // Convert PDF to Image thumbnail if needed
      if (dataUrl.startsWith('data:application/pdf')) {
        setScanStatus('Rendering PDF page to image...');
        const imgDataUrl = await convertPdfDataUrlToImage(dataUrl);
        setPreviewUrl(imgDataUrl);
      } else {
        setPreviewUrl(dataUrl);
      }

      // Trigger AI OCR extraction automatically
      setIsScanning(true);
      setScanStatus('Initializing multi-AI OCR extraction...');
      try {
        const extracted = await extractBankDetailsFromImage(dataUrl, (status) => {
          setScanStatus(status);
        });

        setExtractedInfo(extracted);
        if (extracted.bankName) {
          const matched = matchPhilippineBank(extracted.bankName);
          console.log('[Bank Match Debug]: Scanned bank =', extracted.bankName, '-> Matched dropdown =', matched);
          if (requiredBankPolicy === 'specific_bank' && requiredBankName) {
            setBankName(requiredBankName);
          } else {
            setBankName(matched);
          }
        }
        if (extracted.accountName) setAccountName(extracted.accountName);
        if (extracted.accountNumber) setAccountNumber(extracted.accountNumber);
      } catch (err: any) {
        console.error('AI Document Scan Error:', err);
        setErrorMessage('AI auto-extraction encountered an issue. You can still input details manually.');
      } finally {
        setIsScanning(false);
      }
    };
    reader.readAsDataURL(file);
  };

  const handleSavePaymentAccount = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!accountNumber.trim()) {
      setErrorMessage('Please enter a valid account number.');
      return;
    }
    if (!accountName.trim()) {
      setErrorMessage('Please enter the account holder name.');
      return;
    }

    setIsSaving(true);
    setErrorMessage(null);

    try {
      let documentProofUrl = previewUrl || '';

      // Upload file to Supabase storage if file is selected
      if (selectedFile) {
        const fileExt = selectedFile.name.split('.').pop();
        const fileName = `bank_proof_${scholarId}_${Date.now()}.${fileExt}`;
        const filePath = `bank_documents/${fileName}`;

        // Upload to dedicated bank-proofs bucket (fallback to scholar-documents)
        let { error: uploadErr } = await supabase.storage
          .from('bank-proofs')
          .upload(filePath, selectedFile, { upsert: true });

        if (uploadErr) {
          const fallbackRes = await supabase.storage
            .from('scholar-documents')
            .upload(filePath, selectedFile, { upsert: true });
          uploadErr = fallbackRes.error;
          if (!uploadErr) {
            const { data: publicUrlData } = supabase.storage
              .from('scholar-documents')
              .getPublicUrl(filePath);
            if (publicUrlData?.publicUrl) documentProofUrl = publicUrlData.publicUrl;
          }
        } else {
          const { data: publicUrlData } = supabase.storage
            .from('bank-proofs')
            .getPublicUrl(filePath);
          if (publicUrlData?.publicUrl) {
            documentProofUrl = publicUrlData.publicUrl;
          }
        }
      }

      // Upsert into scholar_payment_accounts
      const payload = {
        scholar_id: scholarId,
        account_type: 'bank_transfer',
        bank_name: bankName,
        account_name: accountName,
        account_number: accountNumber.replace(/\s+/g, ''),
        document_proof_url: documentProofUrl,
        ai_extracted_data: extractedInfo?.rawResponse || {},
        ai_model_used: extractedInfo?.aiModelUsed || 'Manual Entry',
        is_primary: true,
        is_verified: true,
        updated_at: new Date().toISOString(),
      };

      const { data: savedAccount, error: saveErr } = await supabase
        .from('scholar_payment_accounts')
        .insert(payload)
        .select()
        .single();

      if (saveErr) {
        // If conflict on primary index, update existing
        const { data: updatedAccount, error: updateErr } = await supabase
          .from('scholar_payment_accounts')
          .update(payload)
          .eq('scholar_id', scholarId)
          .select()
          .single();

        if (updateErr) throw updateErr;
        onSuccess(updatedAccount);
      } else {
        onSuccess(savedAccount);
      }

      onClose();
    } catch (err: any) {
      console.error('Error saving bank account:', err);
      setErrorMessage(err.message || 'Failed to save bank account details.');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-xs z-50 flex items-center justify-center p-4 overflow-y-auto animate-fade-in">
      <div className="bg-white rounded-3xl max-w-xl w-full p-6 border border-[#D9D2C5] shadow-2xl space-y-6 my-8">
        {/* Header */}
        <div className="flex justify-between items-start border-b border-[#D9D2C5]/60 pb-4">
          <div>
            <div className="flex items-center gap-2">
              <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20 uppercase">
                AI Document Vision
              </span>
              {requiredBankPolicy === 'specific_bank' && (
                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-[#FFF8EE] text-[#C97B2E] border border-[#C97B2E]/30 uppercase">
                  {requiredBankName || 'Landbank'} Required
                </span>
              )}
            </div>
            <h3 className="text-xl font-bold text-[#1A3C2E] font-serif mt-1">
              Upload Bank Card / Proof of Account
            </h3>
            <p className="text-xs text-[#6C6C70]">
              Recipient: <strong className="text-[#1C1C1E]">{scholarName}</strong>
            </p>
          </div>
          <button
            onClick={onClose}
            className="text-[#8E8E93] hover:text-[#1C1C1E] font-bold text-xl cursor-pointer"
          >
            ✕
          </button>
        </div>

        {errorMessage && (
          <div className="p-3 bg-[#FDF2F2] border border-[#B34040]/30 rounded-xl text-xs text-[#B34040] font-medium">
            {errorMessage}
          </div>
        )}

        {/* Upload Zone */}
        <div className="space-y-4">
          <label className="block text-xs font-bold text-[#6C6C70] uppercase">
            1. Select Bank Card Photo or Scanned PDF
          </label>
          <div className="border-2 border-dashed border-[#D9D2C5] hover:border-[#2D5941] rounded-2xl p-6 text-center transition-all bg-[#F9F5EF]/30 relative cursor-pointer group">
            <input
              type="file"
              accept="image/*,.pdf"
              onChange={handleFileChange}
              className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
            />
            {previewUrl ? (
              <div className="space-y-3">
                <img
                  src={previewUrl}
                  alt="Bank Card Preview"
                  className="max-h-40 mx-auto rounded-xl shadow-md border border-[#D9D2C5] object-contain"
                />
                <p className="text-xs text-[#2D5941] font-bold">
                  ✓ File Selected: {selectedFile?.name} (Click to change)
                </p>
              </div>
            ) : (
              <div className="space-y-2">
                <div className="w-12 h-12 rounded-2xl bg-[#EBF5EE] text-[#2D5941] flex items-center justify-center mx-auto text-2xl group-hover:scale-110 transition-transform">
                  💳
                </div>
                <p className="text-xs font-bold text-[#1A3C2E]">
                  Click or drag scanned Landbank / ATM card photo here
                </p>
                <p className="text-[11px] text-[#6C6C70]">
                  Supports JPG, PNG, WebP or PDF scans
                </p>
              </div>
            )}
          </div>
        </div>

        {/* AI Scanner Animation & Status */}
        {isScanning && (
          <div className="bg-[#EBF5EE] border border-[#2D5941]/30 rounded-2xl p-4 flex items-center gap-3 animate-pulse">
            <div className="w-8 h-8 rounded-full bg-[#2D5941] text-white flex items-center justify-center font-bold text-sm shrink-0">
              ⚡
            </div>
            <div>
              <p className="text-xs font-bold text-[#2D5941]">AI Analyzing Bank Document...</p>
              <p className="text-[11px] text-[#2D5941]/80">{scanStatus}</p>
            </div>
          </div>
        )}

        {/* Extracted AI Badge */}
        {extractedInfo && !isScanning && (
          <div className="bg-[#EBF5EE] border border-[#2D5941]/30 rounded-2xl p-3.5 flex items-center justify-between text-xs">
            <div className="flex items-center gap-2">
              <span className="text-base">✨</span>
              <div>
                <span className="font-bold text-[#2D5941]">AI Extraction Successful</span>
                <p className="text-[10px] text-[#6C6C70]">
                  Model: {extractedInfo.aiModelUsed} ({Math.round(extractedInfo.confidenceScore * 100)}% confidence)
                </p>
              </div>
            </div>
            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-[#2D5941] text-white">
              Verified
            </span>
          </div>
        )}

        {/* Form Fields for Review & Confirmation */}
        <form onSubmit={handleSavePaymentAccount} className="space-y-4">
          <label className="block text-xs font-bold text-[#6C6C70] uppercase">
            2. Confirm Extracted Banking Details
          </label>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-[11px] font-bold text-[#6C6C70] uppercase mb-1">
                Bank Name
              </label>
              <select
                value={bankName}
                onChange={(e) => setBankName(e.target.value)}
                required
                disabled={requiredBankPolicy === 'specific_bank'}
                className="w-full px-3.5 py-2 bg-[#F9F5EF]/60 border border-[#D9D2C5] rounded-xl text-xs font-semibold text-[#1C1C1E] focus:outline-none focus:border-[#2D5941]"
              >
                {PH_BANKS.map((b) => (
                  <option key={b} value={b}>
                    {b}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-[11px] font-bold text-[#6C6C70] uppercase mb-1">
                Account Holder Name
              </label>
              <input
                type="text"
                value={accountName}
                onChange={(e) => setAccountName(e.target.value)}
                required
                placeholder="Full Name on Card"
                className="w-full px-3.5 py-2 bg-[#F9F5EF]/60 border border-[#D9D2C5] rounded-xl text-xs font-semibold text-[#1C1C1E] focus:outline-none focus:border-[#2D5941]"
              />
            </div>
          </div>

          <div>
            <label className="block text-[11px] font-bold text-[#6C6C70] uppercase mb-1">
              Bank Account / ATM Card Number
            </label>
            <input
              type="text"
              value={accountNumber}
              onChange={(e) => setAccountNumber(e.target.value)}
              required
              placeholder="e.g. 1234-5678-90"
              className="w-full px-3.5 py-2.5 bg-[#F9F5EF]/60 border border-[#D9D2C5] rounded-xl text-sm font-mono font-bold text-[#2D5941] focus:outline-none focus:border-[#2D5941]"
            />
            <p className="text-[10px] text-[#6C6C70] mt-1">
              Please double check digits match the uploaded card scan before saving.
            </p>
          </div>

          <div className="pt-4 flex justify-end gap-3 border-t border-[#D9D2C5]/60">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-xl border border-[#D9D2C5] text-xs font-bold text-[#6C6C70] hover:bg-[#F9F5EF] cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSaving || isScanning || !accountNumber.trim()}
              className="px-5 py-2 rounded-xl bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold shadow-md cursor-pointer transition-all disabled:opacity-50 flex items-center gap-2"
            >
              {isSaving ? (
                <>
                  <span className="animate-spin text-sm">⏳</span>
                  <span>Saving Account...</span>
                </>
              ) : (
                <span>✓ Confirm & Save Bank Account</span>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
