import React from 'react';
import type { StudentAdminView } from '../types';

interface AdminStudentsTabProps {
  searchQuery: string;
  setSearchQuery: (query: string) => void;
  loadingScholars: boolean;
  students: StudentAdminView[];
  selectedStudent: StudentAdminView | null;
  setSelectedStudent: (student: StudentAdminView | null) => void;
  handleStudentStatus: (id: any, status: 'Active' | 'Suspended') => void;
}

export const AdminStudentsTab: React.FC<AdminStudentsTabProps> = ({
  searchQuery,
  setSearchQuery,
  loadingScholars,
  students,
  selectedStudent,
  setSelectedStudent,
  handleStudentStatus,
}) => {
  return (
    <div className="space-y-6">
      <div className="bg-white rounded-2xl border border-[#D9D2C5] shadow-sm p-6">
        <div className="flex justify-between items-center mb-6">
          <div>
            <h3 className="text-lg font-bold text-[#1A3C2E] font-serif">Scholar Management</h3>
            <p className="text-xs text-[#6C6C70]">Registered scholar directory, profile verification, and account controls</p>
          </div>
          <input
            type="text"
            placeholder="Search scholars by name, school, course..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="px-4 py-2 text-xs rounded-xl border border-[#D9D2C5] focus:outline-none w-72 bg-white"
          />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Scholars List */}
          <div className="lg:col-span-2 space-y-3">
            {loadingScholars ? (
              <div className="p-8 text-center text-xs text-[#6C6C70] italic bg-white rounded-xl border border-[#D9D2C5]">
                Fetching registered scholars from database...
              </div>
            ) : students.length === 0 ? (
              <div className="p-8 text-center text-xs text-[#6C6C70] italic bg-white rounded-xl border border-[#D9D2C5]">
                No scholars currently registered in system.
              </div>
            ) : (
              students
                .filter(s =>
                  s.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                  s.school.toLowerCase().includes(searchQuery.toLowerCase()) ||
                  s.course.toLowerCase().includes(searchQuery.toLowerCase())
                )
                .map(student => (
                  <div
                    key={student.id}
                    onClick={() => setSelectedStudent(student)}
                    className={`p-4 rounded-xl border transition-all cursor-pointer flex justify-between items-center ${
                      selectedStudent?.id === student.id
                        ? 'border-[#2D5941] bg-[#EBF5EE]/30'
                        : 'border-[#D9D2C5] bg-white hover:bg-[#F9F5EF]/50'
                    }`}
                  >
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-sm text-[#1C1C1E]">{student.name}</span>
                        <span className={`text-[9px] font-bold px-1.5 py-0.5 rounded ${
                          student.verificationStatus === 'Verified' ? 'bg-[#EBF5EE] text-[#2D5941]' :
                          student.verificationStatus === 'Pending' ? 'bg-[#FFF8EE] text-[#C97B2E]' :
                          'bg-red-50 text-[#B34040]'
                        }`}>
                          {student.verificationStatus}
                        </span>
                      </div>
                      <p className="text-xs text-[#6C6C70] mt-1">{student.school} • {student.course} ({student.yearLevel}) • GWA: {student.gpa}</p>
                    </div>
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                      student.accountStatus === 'Active' ? 'bg-[#EBF5EE] text-[#2D5941]' : 'bg-red-50 text-[#B34040]'
                    }`}>
                      {student.accountStatus}
                    </span>
                  </div>
                ))
            )}
          </div>

          {/* Detail Panel */}
          <div className="bg-[#F9F5EF]/50 border border-[#D9D2C5] rounded-2xl p-6">
            {selectedStudent ? (
              <div className="space-y-6">
                <div>
                  <h4 className="font-bold text-base text-[#1A3C2E] font-serif">{selectedStudent.name}</h4>
                  <p className="text-xs text-[#6C6C70]">Scholar profile and verification audit</p>
                </div>

                <div className="space-y-3 bg-white p-4 rounded-xl border border-[#D9D2C5] text-xs">
                  <div>
                    <span className="text-[#8E8E93] block uppercase font-bold text-[9px]">Email Address</span>
                    <span className="text-[#1C1C1E] font-medium">{selectedStudent.email}</span>
                  </div>
                  <div>
                    <span className="text-[#8E8E93] block uppercase font-bold text-[9px]">Enrolled Institution</span>
                    <span className="text-[#1C1C1E] font-medium">{selectedStudent.school}</span>
                  </div>
                  <div>
                    <span className="text-[#8E8E93] block uppercase font-bold text-[9px]">Degree Course & Year Level</span>
                    <span className="text-[#1C1C1E] font-medium">{selectedStudent.course} • {selectedStudent.yearLevel}</span>
                  </div>
                  <div>
                    <span className="text-[#8E8E93] block uppercase font-bold text-[9px]">Academic GWA / Grade</span>
                    <span className="text-[#1C1C1E] font-medium font-serif">{selectedStudent.gpa}</span>
                  </div>
                  <div>
                    <span className="text-[#8E8E93] block uppercase font-bold text-[9px]">Citizenship</span>
                    <span className="text-[#1C1C1E] font-medium">{selectedStudent.citizenship}</span>
                  </div>
                  <div>
                    <span className="text-[#8E8E93] block uppercase font-bold text-[9px]">Verification Status</span>
                    <span className="text-[#1C1C1E] font-medium">{selectedStudent.verificationStatus}</span>
                  </div>
                </div>

                <div className="pt-4 border-t border-[#D9D2C5] flex gap-2">
                  {selectedStudent.accountStatus === 'Active' ? (
                    <button
                      type="button"
                      onClick={() => handleStudentStatus(selectedStudent.id, 'Suspended')}
                      className="w-full bg-[#B34040] hover:bg-[#8E2F2F] text-white text-xs font-bold py-2 rounded-xl cursor-pointer border-0"
                    >
                      Suspend Scholar Account
                    </button>
                  ) : (
                    <button
                      type="button"
                      onClick={() => handleStudentStatus(selectedStudent.id, 'Active')}
                      className="w-full bg-[#2D5941] hover:bg-[#1A3C2E] text-white text-xs font-bold py-2 rounded-xl cursor-pointer border-0"
                    >
                      Reactivate Account
                    </button>
                  )}
                </div>
              </div>
            ) : (
              <div className="h-full flex flex-col items-center justify-center text-center py-12 text-[#8E8E93]">
                <p className="text-xs font-medium">Select a scholar from the directory to review profile details.</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
