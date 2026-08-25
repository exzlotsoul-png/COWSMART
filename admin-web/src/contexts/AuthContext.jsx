import React, { createContext, useContext, useState, useEffect } from 'react';
import api from '../lib/axios';

const AuthContext = createContext();

export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const checkAuth = async () => {
      const token = localStorage.getItem('auth_token');
      if (token) {
        try {
          // Fetch user info using sanctum endpoint
          const response = await api.get('/user');
          const userData = response.data.user || response.data;
          
          // Verify if user has admin role (1 = admin)
          if (userData.role === 1 || userData.role === '1' || userData.role === 'admin') {
            setUser(userData);
          } else {
            console.warn("User is not an admin, access denied");
            localStorage.removeItem('auth_token');
            setUser(null);
          }
        } catch (error) {
          console.error("Authentication check failed", error);
          localStorage.removeItem('auth_token');
          setUser(null);
        }
      }
      setLoading(false);
    };

    checkAuth();
  }, []);

  const login = async (email, password) => {
    try {
      const response = await api.post('/login', { email, password });
      if (response.data && (response.data.access_token || response.data.token)) {
        const token = response.data.access_token || response.data.token;
        const userData = response.data.user;

        // Check if user is admin (role 1)
        if (userData.role !== 1 && userData.role !== '1' && userData.role !== 'admin') {
          throw new Error('คุณไม่มีสิทธิ์เข้าใช้งานระบบแอดมิน (สำหรับผู้ดูแลระบบเท่านั้น)');
        }

        localStorage.setItem('auth_token', token);
        setUser(userData);
        return true;
      }
      return false;
    } catch (error) {
      console.error("Login failed", error);
      throw error;
    }
  };

  const logout = async () => {
    try {
      await api.post('/logout');
    } catch (error) {
      console.error("Logout error", error);
    } finally {
      localStorage.removeItem('auth_token');
      setUser(null);
      window.location.href = '/login';
    }
  };

  const value = {
    user,
    loading,
    login,
    logout
  };

  return (
    <AuthContext.Provider value={value}>
      {!loading && children}
    </AuthContext.Provider>
  );
};
