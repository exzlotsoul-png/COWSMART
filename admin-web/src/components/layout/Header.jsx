import React from 'react';
import { LogOut, User, Menu } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import './layout.css';

const Header = ({ onToggleSidebar }) => {
  const { user, logout } = useAuth();

  return (
    <header className="header">
      <div className="header-left">
        <button 
          className="mobile-menu-btn" 
          onClick={onToggleSidebar}
          aria-label="เปิดเมนูนำทาง"
        >
          <Menu size={22} />
        </button>
        <h1 className="header-title">ระบบจัดการข้อมูลพื้นฐาน</h1>
      </div>
      <div className="header-actions">
        <div className="user-profile">
          <User size={18} />
          <span className="user-name-text">{user?.name || 'Admin'}</span>
        </div>
        <button onClick={logout} className="logout-btn" title="ออกจากระบบ">
          <LogOut size={16} />
          <span className="logout-text">ออกจากระบบ</span>
        </button>
      </div>
    </header>
  );
};

export default Header;
