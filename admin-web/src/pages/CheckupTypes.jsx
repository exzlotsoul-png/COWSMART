import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2 } from 'lucide-react';
import api from '../lib/axios';

const CheckupTypes = () => {
  const [checkupTypes, setCheckupTypes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentCheckupType, setCurrentCheckupType] = useState({ checkup_types_id: '', type_name: '' });
  const [isEditing, setIsEditing] = useState(false);

  useEffect(() => {
    fetchCheckupTypes();
  }, []);

  const fetchCheckupTypes = async () => {
    try {
      const response = await api.get('/checkup_types');
      setCheckupTypes(response.data.data || response.data);
    } catch (error) {
      console.error("Error fetching checkup types:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenModal = (checkupType = null) => {
    if (checkupType) {
      setCurrentCheckupType(checkupType);
      setIsEditing(true);
    } else {
      setCurrentCheckupType({ checkup_types_id: '', type_name: '' });
      setIsEditing(false);
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setCurrentCheckupType({ checkup_types_id: '', type_name: '' });
    setIsEditing(false);
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setCurrentCheckupType({ ...currentCheckupType, [name]: value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (isEditing) {
        await api.put(`/checkup_types/${currentCheckupType.checkup_types_id}`, currentCheckupType);
      } else {
        await api.post('/checkup_types', currentCheckupType);
      }
      fetchCheckupTypes();
      handleCloseModal();
    } catch (error) {
      console.error("Error saving checkup type:", error);
      alert("เกิดข้อผิดพลาดในการบันทึกข้อมูล");
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลนี้?")) {
      try {
        await api.delete(`/checkup_types/${id}`);
        fetchCheckupTypes();
      } catch (error) {
        console.error("Error deleting checkup type:", error);
        alert("เกิดข้อผิดพลาดในการลบข้อมูล");
      }
    }
  };

  return (
    <div>
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">จัดการประเภทการตรวจ</h2>
          <button className="btn btn-primary" onClick={() => handleOpenModal()}>
            <Plus size={16} />
            เพิ่มประเภท
          </button>
        </div>

        {loading ? (
          <p>กำลังโหลดข้อมูล...</p>
        ) : (
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>รหัสประเภทการตรวจ</th>
                  <th>ชื่อประเภท</th>
                  <th>จัดการ</th>
                </tr>
              </thead>
              <tbody>
                {checkupTypes.length > 0 ? (
                  checkupTypes.map((type) => (
                    <tr key={type.checkup_types_id}>
                      <td>{type.checkup_types_id}</td>
                      <td>{type.type_name}</td>
                      <td>
                        <div className="action-links">
                          <button className="action-btn edit" onClick={() => handleOpenModal(type)}>
                            <Edit size={16} />
                          </button>
                          <button className="action-btn delete" onClick={() => handleDelete(type.checkup_types_id)}>
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
              <h3 className="modal-title">{isEditing ? 'แก้ไขประเภทการตรวจ' : 'เพิ่มประเภทการตรวจ'}</h3>
              <button className="modal-close" onClick={handleCloseModal}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label" htmlFor="checkup_types_id">รหัสประเภท (เช่น CT01)</label>
                  <input id="checkup_types_id" name="checkup_types_id" type="text" className="form-control" value={currentCheckupType.checkup_types_id} onChange={handleChange} required disabled={isEditing} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="type_name">ชื่อประเภทการตรวจ</label>
                  <input id="type_name" name="type_name" type="text" className="form-control" value={currentCheckupType.type_name} onChange={handleChange} required />
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

export default CheckupTypes;
