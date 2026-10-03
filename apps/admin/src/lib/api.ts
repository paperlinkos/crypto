export const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000/api/v1';

export interface AdminUser {
  id: string;
  email: string;
  name: string;
  role: 'SUPER_ADMIN' | 'ADMIN' | 'COMPLIANCE' | 'SUPPORT';
}

export class AdminApiClient {
  private static tokenKey = 'offramp_admin_token';
  private static userKey = 'offramp_admin_user';

  static getAccessToken(): string | null {
    if (typeof window === 'undefined') return null;
    return localStorage.getItem(this.tokenKey);
  }

  static getCurrentUser(): AdminUser | null {
    if (typeof window === 'undefined') return null;
    const str = localStorage.getItem(this.userKey);
    return str ? JSON.parse(str) : null;
  }

  static setAuth(token: string, user: AdminUser) {
    localStorage.setItem(this.tokenKey, token);
    localStorage.setItem(this.userKey, JSON.stringify(user));
  }

  static clearAuth() {
    localStorage.removeItem(this.tokenKey);
    localStorage.removeItem(this.userKey);
  }

  static async request(endpoint: string, options: RequestInit = {}) {
    const token = this.getAccessToken();
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(options.headers as Record<string, string>),
    };

    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const res = await fetch(`${API_BASE_URL}${endpoint}`, {
      ...options,
      headers,
    });

    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
      const errorMsg = Array.isArray(data.message) ? data.message.join(', ') : (data.message || 'API request failed');
      throw new Error(errorMsg);
    }

    return data;
  }
}
