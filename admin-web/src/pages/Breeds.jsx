import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2, Search } from 'lucide-react';
import api from '../lib/axios';

const Breeds = () => {
  const [breeds, setBreeds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentBreed, setCurrentBreed] = useState({ breed_id: '', name: '', description: '' });
  const [isEditing, setIsEditing] = useState(false);

  useEffect(() => {
    fetchBreeds();
  }, []);

  const fetchBreeds = async () => {
    try {
      const response = await api.get('/breeds');
      // The API might return { data: [...] } or just an array depending on Laravel Resource
      setBreeds(response.data.data || response.data);
    } catch (error) {
      console.error("Error fetching breeds:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenModal = (breed = null) => {
    if (breed) {
      setCurrentBreed(breed);
      setIsEditing(true);
    } else {
      setCurrentBreed({ breed_id: '', name: '', description: '' });
      setIsEditing(false);
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setCurrentBreed({ breed_id: '', name: '', description: '' });
    setIsEditing(false);
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setCurrentBreed({ ...currentBreed, [name]: value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (isEditing) {
        await api.put(`/breeds/${currentBreed.breed_id}`, currentBreed);
      } else {
        await api.post('/breeds', currentBreed);
      }
      fetchBreeds();
      handleCloseModal();
    } catch (error) {
      console.error("Error saving breed:", error);
      alert("เกิดข้อผิดพลาดในการบันทึกข้อมูล");
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลนี้?")) {
      try {
        await api.delete(`/breeds/${id}`);
        fetchBreeds();
      } catch (error) {
        console.error("Error deleting breed:", error);
        alert("เกิดข้อผิดพลาดในการลบข้อมูล");
      }
    }
  };

  return (
    <div>
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">จัดการสายพันธุ์วัว</h2>
          <button className="btn btn-primary" onClick={() => handleOpenModal()}>
            <Plus size={16} />
            เพิ่มสายพันธุ์
          </button>
        </div>

        {loading ? (
          <p>กำลังโหลดข้อมูล...</p>
        ) : (
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>รหัสสายพันธุ์</th>
                  <th>ชื่อสายพันธุ์</th>
                  <th>รายละเอียด</th>
                  <th>จัดการ</th>
                </tr>
              </thead>
              <tbody>
                {breeds.length > 0 ? (
                  breeds.map((breed) => (
                    <tr key={breed.breed_id}>
                      <td>{breed.breed_id}</td>
                      <td>{breed.name}</td>
                      <td>{breed.description}</td>
                      <td>
                        <div className="action-links">
                          <button className="action-btn edit" onClick={() => handleOpenModal(breed)}>
                            <Edit size={16} />
                          </button>
                          <button className="action-btn delete" onClick={() => handleDelete(breed.breed_id)}>
                            <Trash2 size={16} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan="4" style={{ textAlign: 'center' }}>ไม่พบข้อมูล</td>
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
              <h3 className="modal-title">{isEditing ? 'แก้ไขสายพันธุ์' : 'เพิ่มสายพันธุ์ใหม่'}</h3>
              <button className="modal-close" onClick={handleCloseModal}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label" htmlFor="breed_id">รหัสสายพันธุ์</label>
                  <input
                    id="breed_id"
                    name="breed_id"
                    type="text"
                    className="form-control"
                    value={currentBreed.breed_id}
                    onChange={handleChange}
                    required
                    disabled={isEditing} // รหัสไม่ควรเปลี่ยนหลังจากการสร้าง
                  />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="name">ชื่อสายพันธุ์</label>
                  <input
                    id="name"
                    name="name"
                    type="text"
                    className="form-control"
                    value={currentBreed.name}
                    onChange={handleChange}
                    required
                  />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="description">รายละเอียด</label>
                  <textarea
                    id="description"
                    name="description"
                    className="form-control"
                    value={currentBreed.description || ''}
                    onChange={handleChange}
                    rows="3"
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

export default Breeds;
