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
  const menuSections = [
    {
      label: 'ภาพรวม',
      items: [
        { path: '/', icon: <LayoutDashboard className="nav-icon" />, label: 'แดชบอร์ด' },
      ]
    },
    {
      label: 'จัดการผู้ใช้',
      items: [
        { path: '/users', icon: <Users className="nav-icon" />, label: 'ผู้ใช้งาน' },
        { path: '/issue-reports', icon: <MessageSquareWarning className="nav-icon" />, label: 'รายงานการใช้งาน' },
      ]
    },
    {
      label: 'ข้อมูลพื้นฐาน',
      items: [
        { path: '/breeds', icon: <Dna className="nav-icon" />, label: 'สายพันธุ์วัว' },
        { path: '/cow-types', icon: <Sprout className="nav-icon" />, label: 'ประเภทของวัว' },
        { path: '/diseases', icon: <Stethoscope className="nav-icon" />, label: 'โรคและอาการป่วย' },
        { path: '/medicines', icon: <Pill className="nav-icon" />, label: 'รายการยา' },
        { path: '/vaccines', icon: <Syringe className="nav-icon" />, label: 'รายการวัคซีน' },
      ]
    },
    {
      label: 'ตั้งค่าระบบ',
      items: [
        { path: '/checkup-types', icon: <ActivitySquare className="nav-icon" />, label: 'ประเภทกิจกรรม' },
        { path: '/units', icon: <Scale className="nav-icon" />, label: 'หน่วยวัด' },
        { path: '/settings', icon: <CalendarDays className="nav-icon" />, label: 'คำนวณวันคลอด' },
      ]
    }
  ];

  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        CowSmart Admin
      </div>
      <nav className="sidebar-nav">
        {menuSections.map((section, idx) => (
          <div key={idx} className="nav-section">
            <div className="nav-section-label">{section.label}</div>
            {section.items.map((item) => (
              <NavLink
                key={item.path}
                to={item.path}
                className={({ isActive }) => isActive ? "nav-item active" : "nav-item"}
              >
                {item.icon}
                <span>{item.label}</span>
              </NavLink>
            ))}
          </div>
        ))}
      </nav>
    </aside>
  );
};

export default Sidebar;
