import React, { useState, useEffect } from 'react';
import {
  ScrollText,
  X,
  Sparkles,
  Award,
  Briefcase,
  Microscope,
  Building2,
  Pencil,
  Eye,
  Copy,
  Check,
  Send,
} from 'lucide-react';
import { generateScholarAgreementWithAi } from '@/services/aiExtractionService';
import { sendScholarAgreementNotification } from '@/services/notificationService';
import type { ApplicationDetail } from './ReviewApplicationModal';

interface ScholarGuidelinesModalProps {
  isOpen: boolean;
  onClose: () => void;
  application: ApplicationDetail | null;
  providerName?: string;
  showToast?: (msg: string) => void;
}

export const ScholarGuidelinesModal: React.FC<ScholarGuidelinesModalProps> = ({
  isOpen,
  onClose,
  application,
  providerName = 'Scholarship Provider',
  showToast,
}) => {
  const [templateType, setTemplateType] = useState<'merit' | 'need' | 'stem' | 'corporate' | 'general'>('merit');
  const [maintainingGwa, setMaintainingGwa] = useState('1.75');
  const [renewalPolicy, setRenewalPolicy] = useState('Semestral re-evaluation upon submission of COR and Grade Slips');
  const [additionalReqs, setAdditionalReqs] = useState<string>('Attendance at scholar orientation, maintaining full academic load');
  const [customNotes, setCustomNotes] = useState('');
  const [agreementText, setAgreementText] = useState('');
  const [activeTab, setActiveTab] = useState<'edit' | 'preview'>('edit');
  const [isGenerating, setIsGenerating] = useState(false);
  const [aiStatus, setAiStatus] = useState('');
  const [isSending, setIsSending] = useState(false);
  const [hasSent, setHasSent] = useState(false);

  // Generate initial draft on open if empty
  useEffect(() => {
    if (isOpen && application && !agreementText) {
      handleGenerateAi();
    }
  }, [isOpen, application]);

  if (!isOpen || !application) return null;

  const handleGenerateAi = async (overrideType?: 'merit' | 'need' | 'stem' | 'corporate' | 'general') => {
    setIsGenerating(true);
    setAiStatus('Preparing scholarship policy parameters...');

    try {
      const typeToUse = overrideType || templateType;
      const res = await generateScholarAgreementWithAi(
        {
          scholarName: application.name,
          programTitle: application.program,
          providerName: providerName,
          school: application.school,
          course: application.course,
          yearLevel: application.yearLevel,
          maintainingGwa: maintainingGwa,
          stipendAmount: (application as any).stipendAmount || 5000,
          tuitionCovered: true,
          renewalPolicy: renewalPolicy,
          additionalRequirements: additionalReqs.split(',').map(s => s.trim()).filter(Boolean),
          customNotes: customNotes,
          templateType: typeToUse,
        },
        (status) => setAiStatus(status)
      );

      setAgreementText(res.content);
      showToast?.(`Drafted agreement using ${res.aiModelUsed}!`);
    } catch (err: any) {
      console.error('Error generating agreement:', err);
      showToast?.('Error generating agreement with AI. Baseline template applied.');
    } finally {
      setIsGenerating(false);
      setAiStatus('');
    }
  };

  const handleSendToScholar = async () => {
    if (!agreementText.trim()) {
      showToast?.('Please draft the agreement content before sending.');
      return;
    }

    setIsSending(true);
    try {
      await sendScholarAgreementNotification({
        toEmail: application.email,
        toName: application.name,
        programTitle: application.program,
        providerName: providerName,
        agreementContent: agreementText,
        maintainingGwa: maintainingGwa,
        scholarId: application.scholarId,
        applicationId: application.id,
      });

      setHasSent(true);
      showToast?.(`Scholar guidelines and maintaining rules sent to ${application.name}!`);
      setTimeout(() => {
        onClose();
      }, 1200);
    } catch (err) {
      console.error('Error sending agreement notification:', err);
      showToast?.('Error delivering guidelines notification.');
    } finally {
      setIsSending(false);
    }
  };

  const handleCopyClipboard = () => {
    navigator.clipboard.writeText(agreementText);
    showToast?.('Agreement copied to clipboard!');
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs animate-fade-in">
      <div className="bg-white w-full max-w-4xl rounded-3xl border border-[#D9D2C5] shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        
        {/* Header */}
        <div className="bg-[#F9F5EF] border-b border-[#D9D2C5] p-5 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="w-10 h-10 rounded-2xl bg-[#EBF5EE] text-[#2D5941] flex items-center justify-center">
              <ScrollText className="w-5 h-5 text-[#2D5941]" />
            </span>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-lg font-extrabold text-[#1A3C2E] font-serif">
                  Scholar Maintaining Agreement & Guidelines
                </h3>
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-amber-100 text-amber-800 border border-amber-200">
                  Optional
                </span>
              </div>
              <p className="text-xs text-[#6C6C70]">
                Draft and publish academic maintaining terms, grade criteria, and renewal rules for <strong>{application.name}</strong>
              </p>
            </div>
          </div>

          <button
            type="button"
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-white border border-[#D9D2C5] text-[#6C6C70] hover:text-[#1A3C2E] flex items-center justify-center cursor-pointer transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Scholar Quick Info Ribbon */}
        <div className="bg-emerald-900/5 px-6 py-2.5 border-b border-[#D9D2C5]/50 flex flex-wrap items-center justify-between text-xs text-[#1A3C2E] gap-2">
          <div className="flex items-center gap-4">
            <span><strong>Program:</strong> {application.program}</span>
            <span><strong>School:</strong> {application.school}</span>
            <span><strong>Course:</strong> {application.course} ({application.yearLevel || '1st Year'})</span>
          </div>
          <span className="text-[11px] font-mono text-[#2D5941] font-bold">
            Scholar ID: {application.id}
          </span>
        </div>

        {/* Content Body */}
        <div className="p-6 overflow-y-auto space-y-5 flex-1">
          
          {/* Preset Buttons & AI Draft Generator */}
          <div className="bg-[#F9F5EF] p-4 rounded-2xl border border-[#D9D2C5]/70 space-y-3">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
              <span className="text-xs font-extrabold text-[#1A3C2E] uppercase tracking-wider">
                Select Program Policy Template
              </span>
              <button
                type="button"
                onClick={() => handleGenerateAi()}
                disabled={isGenerating}
                className="px-3.5 py-1.5 rounded-xl bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold shadow-xs cursor-pointer border-0 transition-all flex items-center gap-1.5 disabled:opacity-50"
              >
                {isGenerating ? (
                  <>
                    <div className="w-3.5 h-3.5 rounded-full border-2 border-white border-t-transparent animate-spin" />
                    <span>{aiStatus || 'Generating with AI...'}</span>
                  </>
                ) : (
                  <>
                    <Sparkles className="w-3.5 h-3.5" />
                    <span>Draft / Regenerate with AI</span>
                  </>
                )}
              </button>
            </div>

            {/* Template Buttons */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
              {[
                { id: 'merit', label: 'Academic Merit', Icon: Award },
                { id: 'need', label: 'Financial Assistance', Icon: Briefcase },
                { id: 'stem', label: 'STEM & Priority', Icon: Microscope },
                { id: 'corporate', label: 'Foundation / NGO', Icon: Building2 },
              ].map(tpl => {
                const IconComponent = tpl.Icon;
                return (
                  <button
                    key={tpl.id}
                    type="button"
                    onClick={() => {
                      setTemplateType(tpl.id as any);
                      handleGenerateAi(tpl.id as any);
                    }}
                    className={`p-2 rounded-xl text-xs font-bold border transition-all text-left flex items-center gap-2 cursor-pointer ${
                      templateType === tpl.id
                        ? 'bg-white border-[#2D5941] text-[#2D5941] shadow-xs'
                        : 'bg-transparent border-[#D9D2C5] text-[#6C6C70] hover:bg-white/60'
                    }`}
                  >
                    <IconComponent className="w-4 h-4 shrink-0 text-[#2D5941]" />
                    <span className="truncate">{tpl.label}</span>
                  </button>
                );
              })}
            </div>

            {/* Policy Parameters Row */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-1">
              <div>
                <label className="block text-[10px] font-extrabold text-[#6C6C70] uppercase mb-1">
                  Maintaining GWA
                </label>
                <input
                  type="text"
                  value={maintainingGwa}
                  onChange={(e) => setMaintainingGwa(e.target.value)}
                  placeholder="e.g. 1.75 or 85%"
                  className="w-full text-xs px-3 py-1.5 rounded-xl bg-white border border-[#D9D2C5] text-[#1A3C2E] outline-none focus:border-[#2D5941]"
                />
              </div>

              <div>
                <label className="block text-[10px] font-extrabold text-[#6C6C70] uppercase mb-1">
                  Renewal Policy
                </label>
                <input
                  type="text"
                  value={renewalPolicy}
                  onChange={(e) => setRenewalPolicy(e.target.value)}
                  placeholder="e.g. Semestral re-evaluation"
                  className="w-full text-xs px-3 py-1.5 rounded-xl bg-white border border-[#D9D2C5] text-[#1A3C2E] outline-none focus:border-[#2D5941]"
                />
              </div>

              <div>
                <label className="block text-[10px] font-extrabold text-[#6C6C70] uppercase mb-1">
                  Additional Obligations
                </label>
                <input
                  type="text"
                  value={additionalReqs}
                  onChange={(e) => setAdditionalReqs(e.target.value)}
                  placeholder="e.g. Community hours, orientation"
                  className="w-full text-xs px-3 py-1.5 rounded-xl bg-white border border-[#D9D2C5] text-[#1A3C2E] outline-none focus:border-[#2D5941]"
                />
              </div>
            </div>

            <div>
              <label className="block text-[10px] font-extrabold text-[#6C6C70] uppercase mb-1">
                Custom Provider Notes / Contact Instructions (Optional)
              </label>
              <input
                type="text"
                value={customNotes}
                onChange={(e) => setCustomNotes(e.target.value)}
                placeholder="e.g. Please join the official batch orientation on Zoom this Saturday..."
                className="w-full text-xs px-3 py-1.5 rounded-xl bg-white border border-[#D9D2C5] text-[#1A3C2E] outline-none focus:border-[#2D5941]"
              />
            </div>
          </div>

          {/* Editor / Preview Mode Tabs */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <div className="flex items-center p-1 bg-[#F9F5EF] rounded-xl border border-[#D9D2C5]/60">
                <button
                  type="button"
                  onClick={() => setActiveTab('edit')}
                  className={`px-3 py-1 rounded-lg text-xs font-bold cursor-pointer border-0 transition-all flex items-center gap-1.5 ${
                    activeTab === 'edit' ? 'bg-[#1A3C2E] text-white shadow-xs' : 'bg-transparent text-[#6C6C70]'
                  }`}
                >
                  <Pencil className="w-3.5 h-3.5" />
                  <span>Edit Markdown</span>
                </button>
                <button
                  type="button"
                  onClick={() => setActiveTab('preview')}
                  className={`px-3 py-1 rounded-lg text-xs font-bold cursor-pointer border-0 transition-all flex items-center gap-1.5 ${
                    activeTab === 'preview' ? 'bg-[#1A3C2E] text-white shadow-xs' : 'bg-transparent text-[#6C6C70]'
                  }`}
                >
                  <Eye className="w-3.5 h-3.5" />
                  <span>Formatted Preview</span>
                </button>
              </div>

              <span className="text-[11px] text-[#6C6C70]">
                {agreementText.length} characters • Editable
              </span>
            </div>

            {/* Editor Canvas */}
            {activeTab === 'edit' ? (
              <textarea
                value={agreementText}
                onChange={(e) => setAgreementText(e.target.value)}
                rows={13}
                placeholder="The drafted guidelines agreement will appear here. You can customize any section..."
                className="w-full p-4 rounded-2xl bg-white border border-[#D9D2C5] text-[#1A3C2E] font-mono text-xs leading-relaxed outline-none focus:border-[#2D5941] resize-y"
              />
            ) : (
              <div className="p-6 rounded-2xl bg-[#F9F5EF]/40 border border-[#D9D2C5] text-[#1A3C2E] text-xs leading-relaxed max-h-96 overflow-y-auto whitespace-pre-wrap font-sans">
                {agreementText || 'No agreement text drafted yet. Click "Draft / Regenerate with AI" above.'}
              </div>
            )}
          </div>
        </div>

        {/* Footer Actions */}
        <div className="bg-[#F9F5EF] border-t border-[#D9D2C5] p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={handleCopyClipboard}
              className="px-3.5 py-2 rounded-2xl bg-white hover:bg-[#EDE8DE] text-[#1A3C2E] text-xs font-bold border border-[#D9D2C5] cursor-pointer transition-all flex items-center gap-1.5"
            >
              <Copy className="w-3.5 h-3.5" />
              <span>Copy</span>
            </button>
            <span className="text-[11px] text-[#6C6C70]">
              Sending is optional. You can skip if the program has no maintaining criteria.
            </span>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-2xl bg-white hover:bg-[#EDE8DE] text-[#6C6C70] hover:text-[#1A3C2E] text-xs font-bold border border-[#D9D2C5] cursor-pointer transition-all"
            >
              Skip / Close
            </button>
            <button
              type="button"
              onClick={handleSendToScholar}
              disabled={isSending || !agreementText.trim()}
              className="px-5 py-2 rounded-2xl bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold shadow-sm cursor-pointer border-0 transition-all flex items-center gap-2 disabled:opacity-50"
            >
              {isSending ? (
                <>
                  <div className="w-3.5 h-3.5 rounded-full border-2 border-white border-t-transparent animate-spin" />
                  <span>Sending Guidelines...</span>
                </>
              ) : hasSent ? (
                <>
                  <Check className="w-3.5 h-3.5" />
                  <span>Sent Successfully!</span>
                </>
              ) : (
                <>
                  <Send className="w-3.5 h-3.5" />
                  <span>Send Guidelines to Scholar</span>
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
