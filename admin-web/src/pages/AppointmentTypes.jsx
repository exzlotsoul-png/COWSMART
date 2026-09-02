import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2, Search, ArrowUpDown } from 'lucide-react';
import api from '../lib/axios';
import Pagination from '../components/layout/Pagination';
import { useToast } from '../contexts/ToastContext';

const AppointmentTypes = () => {
  const { showToast } = useToast();
  const [types, setTypes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentType, setCurrentType] = useState({ id: '', name: '' });
  const [isEditing, setIsEditing] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [sortOrder, setSortOrder] = useState('newest');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    fetchTypes();
  }, []);

  const fetchTypes = async () => {
    try {
      const response = await api.get('/appointment_types');
      setTypes(response.data.data || response.data);
      setCurrentPage(1);
    } catch (error) {
      console.error("Error fetching appointment types:", error);
      showToast("ไม่สามารถดึงข้อมูลประเภทนัดหมายได้", "error");
    } finally {
      setLoading(false);
    }
  };

  const getNextId = () => {
    let max = 0;
    appointmentTypes.forEach(t => {
      const match = String(t.id || '').match(/(\d+)/);
      if (match) {
        const num = parseInt(match[1], 10);
        if (num > max) max = num;
      }
    });
    return 'AT' + String(max + 1).padStart(2, '0');
  };

  const handleOpenModal = (type = null) => {
    if (type) {
      setCurrentType(type);
      setIsEditing(true);
    } else {
      setCurrentType({ id: getNextId(), name: '' });
      setIsEditing(false);
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setCurrentType({ id: '', name: '' });
    setIsEditing(false);
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setCurrentType({ ...currentType, [name]: value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (isEditing) {
        await api.put(`/appointment_types/${currentType.id}`, currentType);
        showToast(`แก้ไขข้อมูลประเภทนัดหมาย "${currentType.name}" สำเร็จ`, "success");
      } else {
        await api.post('/appointment_types', currentType);
        showToast(`เพิ่มประเภทนัดหมายใหม่ "${currentType.name}" สำเร็จ`, "success");
      }
      fetchTypes();
      handleCloseModal();
    } catch (error) {
      console.error("Error saving appointment type:", error);
      showToast("เกิดข้อผิดพลาดในการบันทึกข้อมูลประเภทนัดหมาย", "error");
    }
  };

  const handleDelete = async (id, name = '') => {
    if (window.confirm(`คุณแน่ใจหรือไม่ว่าต้องการลบประเภทนัดหมาย "${name || id}"?`)) {
      try {
        await api.delete(`/appointment_types/${id}`);
        showToast(`ลบประเภทนัดหมาย "${name || id}" เรียบร้อยแล้ว`, "info");
        fetchTypes();
      } catch (error) {
        console.error("Error deleting appointment type:", error);
        showToast("เกิดข้อผิดพลาดในการลบข้อมูลประเภทนัดหมาย", "error");
      }
    }
  };

  const filteredAndSorted = types
    .filter(t =>
      (t.name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (t.id || '').toLowerCase().includes(searchTerm.toLowerCase())
    )
    .sort((a, b) => {
      const compare = (b.id || '').localeCompare(a.id || '');
      return sortOrder === 'newest' ? compare : -compare;
    });

  const totalPages = Math.ceil(filteredAndSorted.length / itemsPerPage) || 1;
  const currentItems = filteredAndSorted.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  return (
    <div>
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">จัดการประเภทนัดหมาย</h2>
          <button className="btn btn-primary" onClick={() => handleOpenModal()}>
            <Plus size={16} />
            เพิ่มประเภทนัดหมาย
          </button>
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 24px', flexWrap: 'wrap', gap: '16px' }}>
          <div className="search-box" style={{ display: 'flex', alignItems: 'center', backgroundColor: '#f3f4f6', padding: '8px 12px', borderRadius: '8px', width: '300px', flexGrow: 1, maxWidth: '400px' }}>
            <Search size={18} style={{ color: '#9ca3af', marginRight: '8px' }} />
            <input
              type="text"
              placeholder="ค้นหา..."
              style={{ border: 'none', backgroundColor: 'transparent', outline: 'none', width: '100%' }}
              value={searchTerm}
              onChange={(e) => {
                setSearchTerm(e.target.value);
                setCurrentPage(1);
              }}
            />
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
          <p style={{ padding: '24px' }}>กำลังโหลดข้อมูล...</p>
        ) : (
          <>
            <div className="table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th style={{ width: '220px' }}>รหัส</th>
                    <th>ชื่อประเภทนัดหมาย</th>
                    <th style={{ width: '120px', textAlign: 'right', paddingRight: '24px' }}>จัดการ</th>
                  </tr>
                </thead>
                <tbody>
                  {currentItems.length > 0 ? (
                    currentItems.map((type) => (
                      <tr key={type.id}>
                        <td>{type.id}</td>
                        <td style={{ fontWeight: '500' }}>{type.name}</td>
                        <td style={{ textAlign: 'right' }}>
                          <div className="action-links" style={{ justifyContent: 'flex-end', paddingRight: '4px' }}>
                            <button className="action-btn edit" onClick={() => handleOpenModal(type)}>
                              <Edit size={16} />
                            </button>
                            <button className="action-btn delete" onClick={() => handleDelete(type.id, type.name)}>
                              <Trash2 size={16} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan="3" style={{ textAlign: 'center' }}>ไม่พบข้อมูล</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            <Pagination
              currentPage={currentPage}
              totalPages={totalPages}
              onPageChange={setCurrentPage}
              totalItems={filteredAndSorted.length}
              itemsPerPage={itemsPerPage}
            />
          </>
        )}
      </div>

      {isModalOpen && (
        <div className="modal-overlay" onClick={handleCloseModal}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">{isEditing ? 'แก้ไขประเภทนัดหมาย' : 'เพิ่มประเภทนัดหมาย'}</h3>
              <button className="modal-close" onClick={handleCloseModal}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label" htmlFor="id">รหัสประเภท (เช่น APT006)</label>
                  <input id="id" name="id" type="text" className="form-control" value={currentType.id} onChange={handleChange} required disabled={isEditing} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="name">ชื่อประเภทนัดหมาย</label>
                  <input id="name" name="name" type="text" className="form-control" value={currentType.name} onChange={handleChange} required />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-outline" onClick={handleCloseModal}>ยกเลิก</button>
                <button type="submit" className="btn btn-primary">บันทึก</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default AppointmentTypes;
