import React, { useState, useEffect } from 'react';
import { ToggleLeft, ToggleRight, Trash2 } from 'lucide-react';
import api from '../lib/axios';
import { useAuth } from '../contexts/AuthContext';
import Pagination from '../components/layout/Pagination';

const Users = () => {
  const { user: currentUser } = useAuth();
  const [users, setUsers] = useState([]);
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
    } finally {
      setLoading(false);
    }
  };

  const handleToggleActive = async (email, currentStatus) => {
    try {
      const newStatus = !currentStatus;
      await api.put(`/users/${email}`, { is_active: newStatus });
      fetchUsers();
    } catch (error) {
      console.error("Error updating user status:", error);
      alert("เกิดข้อผิดพลาดในการอัปเดตสถานะผู้ใช้งาน");
    }
  };

  // Pagination calculations
  const totalItems = users.length;
  const totalPages = Math.ceil(totalItems / itemsPerPage);
  const indexOfLastItem = currentPage * itemsPerPage;
  const indexOfFirstItem = indexOfLastItem - itemsPerPage;
  const currentUsers = users.slice(indexOfFirstItem, indexOfLastItem);

  return (
    <div>
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">จัดการผู้ใช้งาน</h2>
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
                    <th>Role</th>
                    <th>วันที่สมัคร</th>
                    <th>สถานะ</th>
                    <th>จัดการ</th>
                  </tr>
                </thead>
                <tbody>
                  {currentUsers.length > 0 ? (
                    currentUsers.map((user) => (
                      <tr key={user.email}>
                        <td>{user.email}</td>
                        <td>{user.first_name}</td>
                        <td>{user.last_name}</td>
                        <td>{user.role}</td>
                        <td>{new Date(user.created_at).toLocaleDateString('th-TH')}</td>
                        <td>
                          <span style={{ 
                            padding: '4px 8px', 
                            borderRadius: '12px', 
                            fontSize: '0.85rem',
                            backgroundColor: user.is_active ? '#d1fae5' : '#fee2e2',
                            color: user.is_active ? '#065f46' : '#991b1b'
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
                                style={{ color: user.is_active ? '#10b981' : '#9ca3af' }}
                                onClick={() => handleToggleActive(user.email, user.is_active)}
                                title={user.is_active ? "ปิดใช้งานบัญชี" : "เปิดใช้งานบัญชี"}
                              >
                                {user.is_active ? <ToggleRight size={24} /> : <ToggleLeft size={24} />}
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))
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
