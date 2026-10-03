import React from 'react';
import { cn } from '../lib/utils';
import { LucideIcon } from 'lucide-react';

interface StatCardProps {
  title: string;
  value: string;
  subtitle?: string;
  icon: LucideIcon;
  trend?: string;
  variant?: 'default' | 'emerald' | 'mint';
}

export const StatCard: React.FC<StatCardProps> = ({
  title,
  value,
  subtitle,
  icon: Icon,
  trend,
  variant = 'default',
}) => {
  return (
    <div
      className={cn(
        'p-5 rounded-2xl border transition-all duration-200',
        variant === 'emerald'
          ? 'bg-gradient-to-br from-emerald to-emerald-deep text-white border-emerald'
          : 'bg-white text-gray-900 border-porcelain-border shadow-sm'
      )}
    >
      <div className="flex items-center justify-between">
        <span
          className={cn(
            'text-xs font-bold uppercase tracking-wider',
            variant === 'emerald' ? 'text-mint' : 'text-gray-500'
          )}
        >
          {title}
        </span>
        <div
          className={cn(
            'p-2 rounded-xl',
            variant === 'emerald' ? 'bg-white/10 text-mint' : 'bg-porcelain-sage text-emerald'
          )}
        >
          <Icon className="w-5 h-5" />
        </div>
      </div>
      <div className="mt-3">
        <h3 className="text-2xl font-bold tracking-tight">{value}</h3>
        {(subtitle || trend) && (
          <div className="mt-1 flex items-center space-x-2 text-xs">
            {trend && <span className="text-mint font-semibold">{trend}</span>}
            {subtitle && (
              <span className={variant === 'emerald' ? 'text-white/70' : 'text-gray-500'}>
                {subtitle}
              </span>
            )}
          </div>
        )}
      </div>
    </div>
  );
};
