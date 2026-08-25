import React, { useState, useEffect } from 'react';
import { supabase } from '@/services/supabaseClient';

interface AdminDocumentsTabProps {
  showToast?: (msg: string) => void;
}

export const AdminDocumentsTab: React.FC<AdminDocumentsTabProps> = () => {
  const [documents, setDocuments] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDocuments();
  }, []);

  const fetchDocuments = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('scholarship_applications')
        .select(`
          id,
          submitted_documents,
          updated_at,
          scholar:scholar_id (
            first_name,
            last_name
          ),
          cycle:cycle_id (
            program:program_id (
              provider:provider_id (
                name
              )
            )
          )
        `)
        .not('submitted_documents', 'is', null);

      if (!error && data) {
        const extracted: any[] = [];
        data.forEach((app: any) => {
          const scholarName = app.scholar
            ? `${app.scholar.first_name || ''} ${app.scholar.last_name || ''}`.trim()
            : 'Scholar Student';
          const providerName = app.cycle?.program?.provider?.name || 'Scholarship Provider';
          
          let docsList: any[] = [];
          if (app.submitted_documents?.documents && Array.isArray(app.submitted_documents.documents)) {
            docsList = app.submitted_documents.documents;
          } else if (Array.isArray(app.submitted_documents)) {
            docsList = app.submitted_documents;
          } else if (typeof app.submitted_documents === 'object') {
            docsList = Object.entries(app.submitted_documents).map(([k, v]) => ({ name: k, url: v }));
          }

          docsList.forEach((doc: any, index: number) => {
            extracted.push({
              id: `${app.id}-${index}`,
              scholarName,
              providerName,
              docName: doc.name || doc.document_type || doc.type || `Submitted Document #${index + 1}`,
              status: doc.verification_status || doc.status || 'Verified',
              url: doc.url || doc.file_url,
            });
          });
        });

        setDocuments(extracted);
      }
    } catch (err) {
      console.error('Error fetching admin documents:', err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
      <h3 className="text-lg font-bold text-[#1A3C2E] font-serif mb-4">Document Verification Logs</h3>
      <p className="text-xs text-[#6C6C70] mb-6">
        Track student requirement submissions and provider review logs. System admin provides oversight.
      </p>

      <div className="overflow-x-auto text-xs text-[#6C6C70]">
        <table className="w-full text-left">
          <thead>
            <tr className="border-b border-[#D9D2C5] text-[#1C1C1E] font-bold">
              <th className="py-2.5">Document ID</th>
              <th>Student</th>
              <th>Type / File</th>
              <th>Provider Verification Status</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={4} className="py-8 text-center text-xs text-[#6C6C70] italic">
                  Loading verification document logs...
                </td>
              </tr>
            ) : documents.length === 0 ? (
              <tr>
                <td colSpan={4} className="py-8 text-center text-xs text-[#6C6C70] italic">
                  No document submission logs found.
                </td>
              </tr>
            ) : (
              documents.map((doc, i) => (
                <tr key={doc.id || i} className="border-b border-[#D9D2C5]/50 hover:bg-[#F9F5EF]/50">
                  <td className="py-3 font-semibold text-[#1C1C1E]">DOC-{String(i + 1).padStart(4, '0')}</td>
                  <td>{doc.scholarName}</td>
                  <td>{doc.docName}</td>
                  <td>
                    <span className={`font-bold ${
                      (doc.status || '').toLowerCase() === 'verified' ? 'text-[#2D5941]' :
                      (doc.status || '').toLowerCase() === 'flagged' || (doc.status || '').toLowerCase() === 'rejected' ? 'text-[#B34040]' :
                      'text-[#C97B2E]'
                    }`}>
                      {doc.status || 'Verified'} by {doc.providerName}
                    </span>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
