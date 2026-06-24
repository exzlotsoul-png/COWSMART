import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2 } from 'lucide-react';
import api from '../lib/axios';

const CowTypes = () => {
  const [cowTypes, setCowTypes] = useState([]);
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
                {cowTypes.length > 0 ? (
                  cowTypes.map((type) => (
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
                  ))
                ) : (
                  <tr>
                    <td colSpan="3" style={{ textAlign: 'center' }}>ไม่พบข้อมูล</td>
                  </tr>
                )}
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
