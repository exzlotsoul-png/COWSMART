import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2, Search, ArrowUpDown } from 'lucide-react';
import api from '../lib/axios';

const Medicines = () => {
  const [medicines, setMedicines] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [sortOrder, setSortOrder] = useState('newest');
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [categoryFilter, setCategoryFilter] = useState('all');
  const uniqueCategories = Array.from(new Set(medicines.map(m => m.category).filter(Boolean)));
  const [currentMedicine, setCurrentMedicine] = useState({
    medicine_id: '', category: '', name: '', indications: '', dosage_usage: ''
  });
  const [isEditing, setIsEditing] = useState(false);

  useEffect(() => {
    fetchMedicines();
  }, []);

  const fetchMedicines = async () => {
    try {
      const response = await api.get('/medicines');
      setMedicines(response.data.data || response.data);
    } catch (error) {
      console.error("Error fetching medicines:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenModal = (medicine = null) => {
    if (medicine) {
      setCurrentMedicine(medicine);
      setIsEditing(true);
    } else {
      setCurrentMedicine({ medicine_id: '', category: '', name: '', indications: '', dosage_usage: '' });
      setIsEditing(false);
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setCurrentMedicine({ medicine_id: '', category: '', name: '', indications: '', dosage_usage: '' });
    setIsEditing(false);
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setCurrentMedicine({ ...currentMedicine, [name]: value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (isEditing) {
        await api.put(`/medicines/${currentMedicine.medicine_id}`, currentMedicine);
      } else {
        await api.post('/medicines', currentMedicine);
      }
      fetchMedicines();
      handleCloseModal();
    } catch (error) {
      console.error("Error saving medicine:", error);
      alert("เกิดข้อผิดพลาดในการบันทึกข้อมูล");
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลนี้?")) {
      try {
        await api.delete(`/medicines/${id}`);
        fetchMedicines();
      } catch (error) {
        console.error("Error deleting medicine:", error);
        alert("เกิดข้อผิดพลาดในการลบข้อมูล");
      }
    }
  };

  return (
    <div>
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">จัดการยา</h2>
          <button className="btn btn-primary" onClick={() => handleOpenModal()}>
            <Plus size={16} />
            เพิ่มยา
          </button>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 24px', flexWrap: 'wrap', gap: '16px' }}>
          <div style={{ display: 'flex', gap: '12px', flexGrow: 1, maxWidth: '700px', flexWrap: 'wrap' }}>
            <div className="search-box" style={{ display: 'flex', alignItems: 'center', backgroundColor: '#f3f4f6', padding: '8px 12px', borderRadius: '8px', width: '250px', flexGrow: 1, maxWidth: '350px' }}>
              <Search size={18} style={{ color: '#9ca3af', marginRight: '8px' }} />
              <input 
                type="text" 
                placeholder="ค้นหา..." 
                style={{ border: 'none', backgroundColor: 'transparent', outline: 'none', width: '100%' }}
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
            
            <select
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
              style={{ padding: '8px 12px', borderRadius: '8px', border: '1px solid var(--border-color)', backgroundColor: '#fff', color: 'var(--text-main)', fontSize: '0.875rem' }}
            >
              <option value="all">ทุกหมวดหมู่</option>
              {uniqueCategories.map(cat => (
                <option key={cat} value={cat}>{cat}</option>
              ))}
            </select>
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
                  <th>รหัสยา</th>
                  <th>หมวดหมู่</th>
                  <th>ชื่อยา</th>
                  <th>ข้อบ่งใช้</th>
                  <th>จัดการ</th>
                </tr>
              </thead>
              <tbody>
                {(() => {
                  const filteredAndSorted = medicines
                    .filter(item => {
                      const matchSearch = 
                        (item.name || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
                        String(item.medicine_id || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
                        (item.indications || '').toLowerCase().includes(searchTerm.toLowerCase());
                      
                      const matchCategory = categoryFilter === 'all' || item.category === categoryFilter;

                      return matchSearch && matchCategory;
                    })
                    .sort((a, b) => {
                      const compare = String(b.medicine_id || '').localeCompare(String(a.medicine_id || ''));
                      return sortOrder === 'newest' ? compare : -compare;
                    });
                  
                  if (filteredAndSorted.length > 0) {
                    return filteredAndSorted.map((medicine) => (
                      <tr key={medicine.medicine_id}>
                      <td>{medicine.medicine_id}</td>
                      <td>{medicine.category}</td>
                      <td>{medicine.name}</td>
                      <td style={{ maxWidth: '250px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {medicine.indications}
                      </td>
                      <td>
                        <div className="action-links">
                          <button className="action-btn edit" onClick={() => handleOpenModal(medicine)}>
                            <Edit size={16} />
                          </button>
                          <button className="action-btn delete" onClick={() => handleDelete(medicine.medicine_id)}>
                            <Trash2 size={16} />
                          </button>
                        </div>
                      </td>
                    </tr>
                    ));
                  } else {
                    return (
                      <tr>
                        <td colSpan="5" style={{ textAlign: 'center' }}>ไม่พบข้อมูล</td>
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
              <h3 className="modal-title">{isEditing ? 'แก้ไขข้อมูลยา' : 'เพิ่มข้อมูลยาใหม่'}</h3>
              <button className="modal-close" onClick={handleCloseModal}>&times;</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label" htmlFor="medicine_id">รหัสยา (เช่น MED-0001)</label>
                  <input id="medicine_id" name="medicine_id" type="text" className="form-control" value={currentMedicine.medicine_id} onChange={handleChange} required disabled={isEditing} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="category">หมวดหมู่ยา</label>
                  <input id="category" name="category" type="text" className="form-control" value={currentMedicine.category || ''} onChange={handleChange} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="name">ชื่อยา</label>
                  <input id="name" name="name" type="text" className="form-control" value={currentMedicine.name} onChange={handleChange} required />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="indications">ข้อบ่งใช้</label>
                  <textarea id="indications" name="indications" className="form-control" rows="3" value={currentMedicine.indications || ''} onChange={handleChange} />
                </div>
                <div className="form-group">
                  <label className="form-label" htmlFor="dosage_usage">ขนาดและวิธีใช้</label>
                  <textarea id="dosage_usage" name="dosage_usage" className="form-control" rows="3" value={currentMedicine.dosage_usage || ''} onChange={handleChange} />
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

export default Medicines;
