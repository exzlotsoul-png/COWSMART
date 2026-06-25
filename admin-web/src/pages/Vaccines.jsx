import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2 } from 'lucide-react';
import api from '../lib/axios';
import Pagination from '../components/layout/Pagination';

const Vaccines = () => {
  const [vaccines, setVaccines] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentVaccine, setCurrentVaccine] = useState({
    vaccine_id: '', category: '', name: '', indications: '', dosage_usage: ''
  });
  const [isEditing, setIsEditing] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    fetchVaccines();
  }, []);

  const fetchVaccines = async () => {
    try {
      const response = await api.get('/vaccines');
      setVaccines(response.data.data || response.data);
      setCurrentPage(1);
    } catch (error) {
      console.error("Error fetching vaccines:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenModal = (vaccine = null) => {
    if (vaccine) {
      setCurrentVaccine(vaccine);
      setIsEditing(true);
    } else {
      setCurrentVaccine({ vaccine_id: '', category: '', name: '', indications: '', dosage_usage: '' });
      setIsEditing(false);
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setCurrentVaccine({ vaccine_id: '', category: '', name: '', indications: '', dosage_usage: '' });
    setIsEditing(false);
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setCurrentVaccine({ ...currentVaccine, [name]: value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (isEditing) {
        await api.put(`/vaccines/${currentVaccine.vaccine_id}`, currentVaccine);
      } else {
        await api.post('/vaccines', currentVaccine);
      }
      fetchVaccines();
      handleCloseModal();
    } catch (error) {
      console.error("Error saving vaccine:", error);
      alert("เกิดข้อผิดพลาดในการบันทึกข้อมูล");
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลนี้?")) {
      try {
        await api.delete(`/vaccines/${id}`);
        fetchVaccines();
      } catch (error) {
        console.error("Error deleting vaccine:", error);
        alert("เกิดข้อผิดพลาดในการลบข้อมูล");
      }
    }
  };

  return (
    <div>
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">จัดการวัคซีน</h2>
          <button className="btn btn-primary" onClick={() => handleOpenModal()}>
            <Plus size={16} />
            เพิ่มวัคซีน
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
                    <th>รหัสวัคซีน</th>
                    <th>หมวดหมู่</th>
                    <th>ชื่อวัคซีน</th>
                    <th>ข้อบ่งใช้</th>
                    <th>จัดการ</th>
                  </tr>
                </thead>
                <tbody>
                  {vaccines.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage).length > 0 ? (
                    vaccines.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage).map((vaccine) => (
                      <tr key={vaccine.vaccine_id}>
                        <td>{vaccine.vaccine_id}</td>
                        <td>{vaccine.category}</td>
                        <td>{vaccine.name}</td>
                        <td style={{ maxWidth: '250px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {vaccine.indications}
                        </td>
                        <td>
                          <div className="action-links">
                            <button className="action-btn edit" onClick={() => handleOpenModal(vaccine)}>
                              <Edit size={16} />
                            </button>
                            <button className="action-btn delete" onClick={() => handleDelete(vaccine.vaccine_id)}>
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
              totalPages={Math.ceil(vaccines.length / itemsPerPage)}
              onPageChange={setCurrentPage}
              totalItems={vaccines.length}
              itemsPerPage={itemsPerPage}
            />
          </>
        )}
      </div>

      {isModalOpen && (
        <div className="modal-overlay" onClick={handleCloseModal}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">{isEditing ? 'แก้ไขข้อมูลวัคซีน' : 'เพิ่มข้อมูลวัคซีนใหม่'}</h3>
              <button className="modal-close" onClick={handleCloseModal}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label" htmlFor="vaccine_id">รหัสวัคซีน (เช่น VAC-0001)</label>
                  <input id="vaccine_id" name="vaccine_id" type="text" className="form-control" value={currentVaccine.vaccine_id} onChange={handleChange} required disabled={isEditing} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="category">หมวดหมู่วัคซีน</label>
                  <input id="category" name="category" type="text" className="form-control" value={currentVaccine.category || ''} onChange={handleChange} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="name">ชื่อวัคซีน</label>
                  <input id="name" name="name" type="text" className="form-control" value={currentVaccine.name} onChange={handleChange} required />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="indications">ข้อบ่งใช้</label>
                  <textarea id="indications" name="indications" className="form-control" rows="3" value={currentVaccine.indications || ''} onChange={handleChange} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="dosage_usage">ขนาดและวิธีใช้</label>
                  <textarea id="dosage_usage" name="dosage_usage" className="form-control" rows="3" value={currentVaccine.dosage_usage || ''} onChange={handleChange} />
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

export default Vaccines;
