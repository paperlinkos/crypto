import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'OffRamp Operations Console',
  description: 'Institutional-grade crypto-to-fiat off-ramp administration and compliance portal',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-porcelain text-obsidian antialiased selection:bg-mint selection:text-obsidian">
        {children}
      </body>
    </html>
  );
}
