import React from 'react';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline';
  children: React.ReactNode;
}

export const Button: React.FC<ButtonProps> = ({
  variant = 'primary',
  children,
  className = '',
  ...props
}) => {
  const baseStyle =
    'px-6 py-3 rounded-xl font-semibold transition-all duration-200 cursor-pointer text-sm tracking-wide inline-flex items-center justify-center gap-2 border';

  let variantStyle = '';
  switch (variant) {
    case 'primary':
      variantStyle = 'bg-[#2D5941] hover:bg-[#1A3C2E] text-white border-transparent shadow-md hover:shadow-lg';
      break;
    case 'secondary':
      variantStyle = 'bg-[#C97B2E] hover:bg-[#7A4A15] text-white border-transparent shadow-md';
      break;
    case 'outline':
      variantStyle = 'bg-transparent text-[#2D5941] border-[#2D5941] hover:bg-[#2D5941] hover:text-white';
      break;
  }

  return (
    <button className={`${baseStyle} ${variantStyle} ${className}`} {...props}>
      {children}
    </button>
  );
};
