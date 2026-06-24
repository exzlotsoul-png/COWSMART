import React from 'react';
import { LogOut, User } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import './layout.css';

const Header = () => {
  const { user, logout } = useAuth();

  return (
    <header className="header">
      <h1 className="header-title">ระบบจัดการข้อมูลพื้นฐาน</h1>
      <div className="header-actions">
        <div className="user-profile">
          <User size={18} />
          <span>{user?.name || 'Admin'}</span>
        </div>
        <button onClick={logout} className="logout-btn">
          <LogOut size={16} />
          ออกจากระบบ
        </button>
      </div>
    </header>
  );
};

export default Header;
