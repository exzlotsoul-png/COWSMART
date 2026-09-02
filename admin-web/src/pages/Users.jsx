import React, { useState, useEffect } from 'react';
import { ToggleLeft, ToggleRight, Trash2, Search, ArrowUpDown } from 'lucide-react';
import api from '../lib/axios';
import { useAuth } from '../contexts/AuthContext';
import { useToast } from '../contexts/ToastContext';
import Pagination from '../components/layout/Pagination';

const Users = () => {
  const { user: currentUser } = useAuth();
  const { showToast } = useToast();
  const [users, setUsers] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [sortOrder, setSortOrder] = useState('newest');
  const [roleFilter, setRoleFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const uniqueRoles = Array.from(new Set(users.map(u => u.role).filter(Boolean)));
  const [loading, setLoading] = useState(true);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      const response = await api.get('/users');
      setUsers(response.data.data || response.data);
      setCurrentPage(1); // reset to page 1 on fetch
    } catch (error) {
      console.error("Error fetching users:", error);
      showToast("ไม่สามารถดึงข้อมูลผู้ใช้งานได้", "error");
    } finally {
      setLoading(false);
    }
  };

  const handleToggleActive = async (email, currentStatus, userName = '') => {
    try {
      const newStatus = !currentStatus;
      await api.put(`/users/${email}`, { is_active: newStatus });
      showToast(`${newStatus ? 'เปิดใช้งาน' : 'ระงับการใช้งาน'} บัญชี "${userName || email}" เรียบร้อยแล้ว`, newStatus ? "success" : "info");
      fetchUsers();
    } catch (error) {
      console.error("Error updating user status:", error);
      showToast("เกิดข้อผิดพลาดในการอัปเดตสถานะผู้ใช้งาน", "error");
    }
  };

  // Pagination calculations
  const filteredAndSorted = users
    .filter(item => {
      const isAdmin = item.role === 1 || item.role === '1' || item.role === 'admin';
      const roleText = isAdmin ? 'แอดมิน admin' : 'ผู้ใช้ user';

      const matchSearch = 
        (item.first_name || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
        (item.last_name || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
        (item.email || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
        roleText.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchRole = roleFilter === 'all' || 
        (roleFilter === 'admin' && isAdmin) || 
        (roleFilter === 'user' && !isAdmin) || 
        item.role === roleFilter;

      const matchStatus = statusFilter === 'all' || 
        (statusFilter === 'active' && item.is_active) || 
        (statusFilter === 'inactive' && !item.is_active);

      return matchSearch && matchRole && matchStatus;
    })
    .sort((a, b) => {
      const compare = (b.email || '').localeCompare(a.email || '');
      return sortOrder === 'newest' ? compare : -compare;
    });
  const totalItems = filteredAndSorted.length;
  const totalPages = Math.ceil(totalItems / itemsPerPage) || 1;
  const indexOfLastItem = currentPage * itemsPerPage;
  const indexOfFirstItem = indexOfLastItem - itemsPerPage;
  const currentUsers = filteredAndSorted.slice(indexOfFirstItem, indexOfLastItem);

  return (
    <div>
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">จัดการผู้ใช้งาน</h2>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 24px', flexWrap: 'wrap', gap: '16px' }}>
          <div style={{ display: 'flex', gap: '12px', flexGrow: 1, maxWidth: '700px', flexWrap: 'wrap' }}>
            <div className="search-box" style={{ display: 'flex', alignItems: 'center', backgroundColor: '#f3f4f6', padding: '8px 12px', borderRadius: '8px', width: '250px', flexGrow: 1, maxWidth: '350px' }}>
              <Search size={18} style={{ color: '#9ca3af', marginRight: '8px' }} />
              <input 
                type="text" 
                placeholder="ค้นหา..." 
                style={{ border: 'none', backgroundColor: 'transparent', outline: 'none', width: '100%' }}
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
            
            <select
              value={roleFilter}
              onChange={(e) => { setRoleFilter(e.target.value); setCurrentPage(1); }}
              style={{ padding: '8px 12px', borderRadius: '8px', border: '1px solid var(--border-color)', backgroundColor: '#fff', color: 'var(--text-main)', fontSize: '0.875rem' }}
            >
              <option value="all">ทุกบทบาท</option>
              <option value="admin">แอดมิน</option>
              <option value="user">ผู้ใช้</option>
            </select>

            <select
              value={statusFilter}
              onChange={(e) => { setStatusFilter(e.target.value); setCurrentPage(1); }}
              style={{ padding: '8px 12px', borderRadius: '8px', border: '1px solid var(--border-color)', backgroundColor: '#fff', color: 'var(--text-main)', fontSize: '0.875rem' }}
            >
              <option value="all">ทุกสถานะ</option>
              <option value="active">เปิดใช้งาน</option>
              <option value="inactive">ปิดใช้งาน</option>
            </select>
          </div>
          <button 
            className="btn btn-outline" 
            style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
            onClick={() => setSortOrder(sortOrder === 'newest' ? 'oldest' : 'newest')}
          >
            <ArrowUpDown size={16} />
            {sortOrder === 'newest' ? 'เรียง: ใหม่ไปเก่า' : 'เรียง: เก่าไปใหม่'}
          </button>
        </div>


        {loading ? (
          <p>กำลังโหลดข้อมูล...</p>
        ) : (
          <>
            <div className="table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>อีเมล</th>
                    <th>ชื่อ</th>
                    <th>นามสกุล</th>
                    <th>บทบาท</th>
                    <th>วันที่สมัคร</th>
                    <th>สถานะ</th>
                    <th>จัดการ</th>
                  </tr>
                </thead>
                <tbody>
                  {currentUsers.length > 0 ? (
                    currentUsers.map((user) => {
                      const isAdmin = user.role === 1 || user.role === '1' || user.role === 'admin';
                      return (
                        <tr key={user.email}>
                          <td>{user.email}</td>
                          <td>{user.first_name}</td>
                          <td>{user.last_name}</td>
                          <td>
                            <span style={{ 
                              display: 'inline-block',
                              whiteSpace: 'nowrap',
                              padding: '4px 10px', 
                              borderRadius: '10px', 
                              fontSize: '0.8rem',
                              fontWeight: '600',
                              backgroundColor: isAdmin ? '#ede9fe' : '#f3f4f6',
                              color: isAdmin ? '#6d28d9' : '#4b5563',
                              border: isAdmin ? '1px solid #ddd6fe' : '1px solid #e5e7eb',
                            }}>
                              {isAdmin ? 'แอดมิน' : 'ผู้ใช้'}
                            </span>
                          </td>
                          <td>{new Date(user.created_at).toLocaleDateString('th-TH')}</td>
                          <td>
                            <span style={{ 
                              display: 'inline-block',
                              whiteSpace: 'nowrap',
                              padding: '4px 12px', 
                              borderRadius: '12px', 
                              fontSize: '0.85rem',
                              fontWeight: '700',
                              backgroundColor: user.is_active ? 'var(--primary-light)' : '#fee2e2',
                              color: user.is_active ? 'var(--primary-color)' : '#991b1b'
                            }}>
                              {user.is_active ? 'เปิดใช้งาน' : 'ปิดใช้งาน'}
                            </span>
                          </td>
                          <td>
                            <div className="action-links">
                              {currentUser?.email === user.email ? (
                                <span style={{ color: '#9ca3af', fontSize: '0.85rem' }}>บัญชีของคุณ</span>
                              ) : (
                                <button 
                                  className="action-btn" 
                                  style={{ color: user.is_active ? 'var(--primary-color)' : '#9ca3af' }}
                                  onClick={() => handleToggleActive(user.email, user.is_active, `${user.first_name || ''} ${user.last_name || ''}`.trim())}
                                  title={user.is_active ? "ปิดใช้งานบัญชี" : "เปิดใช้งานบัญชี"}
                                >
                                  {user.is_active ? <ToggleRight size={24} /> : <ToggleLeft size={24} />}
                                </button>
                              )}
                            </div>
                          </td>
                        </tr>
                      );
                    })
                  ) : (
                    <tr>
                      <td colSpan="7" style={{ textAlign: 'center' }}>ไม่พบข้อมูล</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            <Pagination
              currentPage={currentPage}
              totalPages={totalPages}
              onPageChange={setCurrentPage}
              totalItems={totalItems}
              itemsPerPage={itemsPerPage}
            />
          </>
        )}
      </div>
    </div>
  );
};

export default Users;
