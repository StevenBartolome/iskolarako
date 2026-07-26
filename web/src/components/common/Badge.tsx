import React from 'react';

interface BadgeProps {
  status: 'Approved' | 'Pending' | 'Released';
}

export const Badge: React.FC<BadgeProps> = ({ status }) => {
  let styles = 'bg-gray-100 text-gray-800';

  if (status === 'Approved') {
    styles = 'bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20';
  } else if (status === 'Pending') {
    styles = 'bg-[#FDF3E3] text-[#C97B2E] border border-[#C97B2E]/20';
  } else if (status === 'Released') {
    styles = 'bg-[#EAF3FB] text-[#2A6BA8] border border-[#2A6BA8]/20';
  }

  return (
    <span className={`px-3 py-1 text-xs font-semibold rounded-full uppercase tracking-wider ${styles}`}>
      {status}
    </span>
  );
};
