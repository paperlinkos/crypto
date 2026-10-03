import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatFiatMinor(minorAmount: any, currency = 'NGN'): string {
  if (minorAmount == null) return currency === 'NGN' ? '₦0.00' : '₵0.00';
  const minor = typeof minorAmount === 'bigint' ? Number(minorAmount) : Number(minorAmount) || 0;
  const major = minor / 100;
  const symbol = currency === 'GHS' ? '₵' : '₦';
  return `${symbol}${major.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

export function formatCryptoMinor(minorAmount: any, asset: string): string {
  if (minorAmount == null) return '0.00';
  const minor = Number(minorAmount) || 0;
  if (asset.toUpperCase() === 'BTC') {
    return (minor / 100000000).toLocaleString('en-US', { minimumFractionDigits: 8 });
  }
  return (minor / 1000000).toLocaleString('en-US', { minimumFractionDigits: 2 });
}
