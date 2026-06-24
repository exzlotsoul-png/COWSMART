import React from 'react';
import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  Dna,
  Sprout,
  Stethoscope,
  Pill,
  Syringe,
  ActivitySquare,
  Tractor,
  Users,
  MessageSquareWarning,
  Scale,
  CalendarDays
} from 'lucide-react';
import './layout.css';

const Sidebar = () => {
  const menuItems = [
    { path: '/', icon: <LayoutDashboard className="nav-icon" />, label: 'แดชบอร์ด' },
    { path: '/users', icon: <Users className="nav-icon" />, label: 'ผู้ใช้งาน' },
    { path: '/breeds', icon: <Dna className="nav-icon" />, label: 'สายพันธุ์วัว' },
    { path: '/diseases', icon: <Stethoscope className="nav-icon" />, label: 'โรคและอาการป่วย' },
    { path: '/medicines', icon: <Pill className="nav-icon" />, label: 'รายการยา' },
    { path: '/vaccines', icon: <Syringe className="nav-icon" />, label: 'รายการวัคซีน' },
    { path: '/issue-reports', icon: <MessageSquareWarning className="nav-icon" />, label: 'รายงานการใช้งาน' },
    { path: '/cow-types', icon: <Sprout className="nav-icon" />, label: 'ประเภทของวัว' },
    { path: '/checkup-types', icon: <ActivitySquare className="nav-icon" />, label: 'ประเภทกิจกรรม' },
    { path: '/units', icon: <Scale className="nav-icon" />, label: 'หน่วยวัด' },
    { path: '/settings', icon: <CalendarDays className="nav-icon" />, label: 'กำหนดการคำนวณวันคลอด' },
  ];

  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        CowSmart Admin
      </div>
      <nav className="sidebar-nav">
        {menuItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) => isActive ? "nav-item active" : "nav-item"}
          >
            {item.icon}
            <span>{item.label}</span>
          </NavLink>
        ))}
      </nav>
    </aside>
  );
};

export default Sidebar;
