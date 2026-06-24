import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2 } from 'lucide-react';
import api from '../lib/axios';

const Units = () => {
  const [units, setUnits] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentUnit, setCurrentUnit] = useState({ unit_id: '', name: '', type: '', abbreviation: '' });
  const [isEditing, setIsEditing] = useState(false);

  useEffect(() => {
    fetchUnits();
  }, []);

  const fetchUnits = async () => {
    try {
      const response = await api.get('/units');
      setUnits(response.data.data || response.data);
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

        {loading ? (
          <p>กำลังโหลดข้อมูล...</p>
        ) : (
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
                {units.length > 0 ? (
                  units.map((unit) => (
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
