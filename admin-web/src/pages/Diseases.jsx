import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2, Search, ArrowUpDown } from 'lucide-react';
import api from '../lib/axios';

const Diseases = () => {
  const [diseases, setDiseases] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [sortOrder, setSortOrder] = useState('newest');
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentDisease, setCurrentDisease] = useState({
    disease_id: '', name: '', cause: '', symptoms: '', observation: '', treatment: '', prevention: ''
  });
  const [isEditing, setIsEditing] = useState(false);

  useEffect(() => {
    fetchDiseases();
  }, []);

  const fetchDiseases = async () => {
    try {
      const response = await api.get('/diseases');
      setDiseases(response.data.data || response.data);
    } catch (error) {
      console.error("Error fetching diseases:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenModal = (disease = null) => {
    if (disease) {
      setCurrentDisease(disease);
      setIsEditing(true);
    } else {
      setCurrentDisease({ disease_id: '', name: '', cause: '', symptoms: '', observation: '', treatment: '', prevention: '' });
      setIsEditing(false);
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setCurrentDisease({ disease_id: '', name: '', cause: '', symptoms: '', observation: '', treatment: '', prevention: '' });
    setIsEditing(false);
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setCurrentDisease({ ...currentDisease, [name]: value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (isEditing) {
        await api.put(`/diseases/${currentDisease.disease_id}`, currentDisease);
      } else {
        await api.post('/diseases', currentDisease);
      }
      fetchDiseases();
      handleCloseModal();
    } catch (error) {
      console.error("Error saving disease:", error);
      alert("เกิดข้อผิดพลาดในการบันทึกข้อมูล");
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลนี้?")) {
      try {
        await api.delete(`/diseases/${id}`);
        fetchDiseases();
      } catch (error) {
        console.error("Error deleting disease:", error);
        alert("เกิดข้อผิดพลาดในการลบข้อมูล");
      }
    }
  };

  return (
    <div>
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">จัดการโรคและอาการป่วย</h2>
          <button className="btn btn-primary" onClick={() => handleOpenModal()}>
            <Plus size={16} />
            เพิ่มโรค/อาการป่วย
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
                  <th>รหัสโรค</th>
                  <th>ชื่อโรค/อาการ</th>
                  <th>ลักษณะอาการ</th>
                  <th>จัดการ</th>
                </tr>
              </thead>
              <tbody>
                {diseases.length > 0 ? (
                  diseases.map((disease) => (
                    <tr key={disease.disease_id}>
                      <td>{disease.disease_id}</td>
                      <td>{disease.name}</td>
                      <td style={{ maxWidth: '300px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {disease.symptoms}
                      </td>
                      <td>
                        <div className="action-links">
                          <button className="action-btn edit" onClick={() => handleOpenModal(disease)}>
                            <Edit size={16} />
                          </button>
                          <button className="action-btn delete" onClick={() => handleDelete(disease.disease_id)}>
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
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '600px', maxHeight: '90vh', overflowY: 'auto' }}>
            <div className="modal-header">
              <h3 className="modal-title">{isEditing ? 'แก้ไขข้อมูลโรค' : 'เพิ่มข้อมูลโรคใหม่'}</h3>
              <button className="modal-close" onClick={handleCloseModal}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label" htmlFor="disease_id">รหัสโรค (เช่น DIS-0001)</label>
                  <input id="disease_id" name="disease_id" type="text" className="form-control" value={currentDisease.disease_id} onChange={handleChange} required disabled={isEditing} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="name">ชื่อโรค/อาการป่วย</label>
                  <input id="name" name="name" type="text" className="form-control" value={currentDisease.name} onChange={handleChange} required />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="cause">สาเหตุการเกิดโรค</label>
                  <textarea id="cause" name="cause" className="form-control" rows="2" value={currentDisease.cause || ''} onChange={handleChange} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="symptoms">ลักษณะอาการ</label>
                  <textarea id="symptoms" name="symptoms" className="form-control" rows="2" value={currentDisease.symptoms || ''} onChange={handleChange} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="observation">วิธีสังเกตอาการ</label>
                  <textarea id="observation" name="observation" className="form-control" rows="2" value={currentDisease.observation || ''} onChange={handleChange} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="treatment">วิธีดูแลรักษาเบื้องต้น</label>
                  <textarea id="treatment" name="treatment" className="form-control" rows="2" value={currentDisease.treatment || ''} onChange={handleChange} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="prevention">การควบคุม/ป้องกัน</label>
                  <textarea id="prevention" name="prevention" className="form-control" rows="2" value={currentDisease.prevention || ''} onChange={handleChange} />
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

export default Diseases;
