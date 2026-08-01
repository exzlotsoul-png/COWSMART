import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2, Search, ArrowUpDown } from 'lucide-react';
import api from '../lib/axios';
import Pagination from '../components/layout/Pagination';

const Units = () => {
  const [units, setUnits] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [sortOrder, setSortOrder] = useState('newest');
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentUnit, setCurrentUnit] = useState({ unit_id: '', name: '', type: '', abbreviation: '' });
  const [isEditing, setIsEditing] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    fetchUnits();
  }, []);

  const fetchUnits = async () => {
    try {
      const response = await api.get('/units');
      setUnits(response.data.data || response.data);
      setCurrentPage(1);
    } catch (error) {
      console.error("Error fetching units:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenModal = (unit = null) => {
    if (unit) {
      setCurrentUnit(unit);
      setIsEditing(true);
    } else {
      setCurrentUnit({ unit_id: '', name: '', type: '', abbreviation: '' });
      setIsEditing(false);
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setCurrentUnit({ unit_id: '', name: '', type: '', abbreviation: '' });
    setIsEditing(false);
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setCurrentUnit({ ...currentUnit, [name]: value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (isEditing) {
        await api.put(`/units/${currentUnit.unit_id}`, currentUnit);
      } else {
        await api.post('/units', currentUnit);
      }
      fetchUnits();
      handleCloseModal();
    } catch (error) {
      console.error("Error saving unit:", error);
      alert("เกิดข้อผิดพลาดในการบันทึกข้อมูล");
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลนี้?")) {
      try {
        await api.delete(`/units/${id}`);
        fetchUnits();
      } catch (error) {
        console.error("Error deleting unit:", error);
        alert("เกิดข้อผิดพลาดในการลบข้อมูล");
      }
    }
  };

  const filteredAndSorted = units
    .filter(item => 
      (item.name || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
      (item.abbreviation || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (item.type || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      String(item.unit_id || '').toLowerCase().includes(searchTerm.toLowerCase())
    )
    .sort((a, b) => {
      const compare = String(b.unit_id || '').localeCompare(String(a.unit_id || ''));
      return sortOrder === 'newest' ? compare : -compare;
    });

  const totalPages = Math.ceil(filteredAndSorted.length / itemsPerPage) || 1;
  const currentItems = filteredAndSorted.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  return (
    <div>
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">จัดการหน่วยวัด</h2>
          <button className="btn btn-primary" onClick={() => handleOpenModal()}>
            <Plus size={16} />
            เพิ่มหน่วยวัด
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
                    <th>รหัส</th>
                    <th>ชื่อหน่วยวัด</th>
                    <th>ตัวย่อ</th>
                    <th>ประเภทการวัด</th>
                    <th>จัดการ</th>
                  </tr>
                </thead>
                <tbody>
                  {currentItems.length > 0 ? (
                    currentItems.map((unit) => (
                      <tr key={unit.unit_id}>
                        <td>{unit.unit_id}</td>
                        <td>{unit.name}</td>
                        <td>{unit.abbreviation}</td>
                        <td>{unit.type}</td>
                        <td>
                          <div className="action-links">
                            <button className="action-btn edit" onClick={() => handleOpenModal(unit)}>
                              <Edit size={16} />
                            </button>
                            <button className="action-btn delete" onClick={() => handleDelete(unit.unit_id)}>
                              <Trash2 size={16} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan="5" style={{ textAlign: 'center' }}>ไม่พบข้อมูล</td>
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
              <h3 className="modal-title">{isEditing ? 'แก้ไขหน่วยวัด' : 'เพิ่มหน่วยวัดใหม่'}</h3>
              <button className="modal-close" onClick={handleCloseModal}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label" htmlFor="name">ชื่อหน่วยวัด (เช่น กิโลกรัม, ซีซี)</label>
                  <input id="name" name="name" type="text" className="form-control" value={currentUnit.name} onChange={handleChange} required />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="abbreviation">ตัวย่อ (เช่น kg, cc)</label>
                  <input id="abbreviation" name="abbreviation" type="text" className="form-control" value={currentUnit.abbreviation || ''} onChange={handleChange} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="type">ประเภทการวัด (เช่น น้ำหนัก, ปริมาตร)</label>
                  <select id="type" name="type" className="form-control" value={currentUnit.type || ''} onChange={handleChange}>
                    <option value="">-- เลือกประเภท --</option>
                    <option value="weight">น้ำหนัก</option>
                    <option value="volume">ปริมาตร</option>
                    <option value="length">ความยาว/ส่วนสูง</option>
                    <option value="other">อื่นๆ</option>
                  </select>
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

export default Units;
