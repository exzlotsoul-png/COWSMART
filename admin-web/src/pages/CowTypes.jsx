import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2, Search, ArrowUpDown } from 'lucide-react';
import api from '../lib/axios';

const CowTypes = () => {
  const [cowTypes, setCowTypes] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [sortOrder, setSortOrder] = useState('newest');
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentCowType, setCurrentCowType] = useState({ cow_type_id: '', cow_type_name: '' });
  const [isEditing, setIsEditing] = useState(false);

  useEffect(() => {
    fetchCowTypes();
  }, []);

  const fetchCowTypes = async () => {
    try {
      const response = await api.get('/cow_types');
      setCowTypes(response.data.data || response.data);
    } catch (error) {
      console.error("Error fetching cow types:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenModal = (cowType = null) => {
    if (cowType) {
      setCurrentCowType(cowType);
      setIsEditing(true);
    } else {
      setCurrentCowType({ cow_type_id: '', cow_type_name: '' });
      setIsEditing(false);
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setCurrentCowType({ cow_type_id: '', cow_type_name: '' });
    setIsEditing(false);
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setCurrentCowType({ ...currentCowType, [name]: value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (isEditing) {
        await api.put(`/cow_types/${currentCowType.cow_type_id}`, currentCowType);
      } else {
        await api.post('/cow_types', currentCowType);
      }
      fetchCowTypes();
      handleCloseModal();
    } catch (error) {
      console.error("Error saving cow type:", error);
      alert("เกิดข้อผิดพลาดในการบันทึกข้อมูล");
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลนี้?")) {
      try {
        await api.delete(`/cow_types/${id}`);
        fetchCowTypes();
      } catch (error) {
        console.error("Error deleting cow type:", error);
        alert("เกิดข้อผิดพลาดในการลบข้อมูล");
      }
    }
  };

  return (
    <div>
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">จัดการประเภทวัว</h2>
          <button className="btn btn-primary" onClick={() => handleOpenModal()}>
            <Plus size={16} />
            เพิ่มประเภทวัว
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
              onChange={(e) => setSearchTerm(e.target.value)}
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
          <p>กำลังโหลดข้อมูล...</p>
        ) : (
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>รหัสประเภทวัว</th>
                  <th>ชื่อประเภท</th>
                  <th>จัดการ</th>
                </tr>
              </thead>
              <tbody>
                {(() => {
                  const filteredAndSorted = cowTypes
                    .filter(item => 
                      (item.cow_type_name || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
                        String(item.cow_type_id || '').toLowerCase().includes(searchTerm.toLowerCase())
                    )
                    .sort((a, b) => {
                      const compare = String(b.cow_type_id || '').localeCompare(String(a.cow_type_id || ''));
                      return sortOrder === 'newest' ? compare : -compare;
                    });
                  
                  if (filteredAndSorted.length > 0) {
                    return filteredAndSorted.map((type) => (
                    <tr key={type.cow_type_id}>
                      <td>{type.cow_type_id}</td>
                      <td>{type.cow_type_name}</td>
                      <td>
                        <div className="action-links">
                          <button className="action-btn edit" onClick={() => handleOpenModal(type)}>
                            <Edit size={16} />
                          </button>
                          <button className="action-btn delete" onClick={() => handleDelete(type.cow_type_id)}>
                            <Trash2 size={16} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ));
                  } else {
                    return (
                      <tr>
                        <td colSpan="3" style={{ textAlign: 'center' }}>ไม่พบข้อมูล</td>
                      </tr>
                    );
                  }
                })()}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {isModalOpen && (
        <div className="modal-overlay" onClick={handleCloseModal}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">{isEditing ? 'แก้ไขประเภทวัว' : 'เพิ่มประเภทวัวใหม่'}</h3>
              <button className="modal-close" onClick={handleCloseModal}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label" htmlFor="cow_type_id">รหัสประเภทวัว</label>
                  <input
                    id="cow_type_id"
                    name="cow_type_id"
                    type="text"
                    className="form-control"
                    value={currentCowType.cow_type_id}
                    onChange={handleChange}
                    required
                    disabled={isEditing}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="cow_type_name">ชื่อประเภทวัว</label>
                  <input
                    id="cow_type_name"
                    name="cow_type_name"
                    type="text"
                    className="form-control"
                    value={currentCowType.cow_type_name}
                    onChange={handleChange}
                    required
                  />
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

export default CowTypes;
