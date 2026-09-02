import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2, Search, ArrowUpDown } from 'lucide-react';
import api from '../lib/axios';
import Pagination from '../components/layout/Pagination';
import { useToast } from '../contexts/ToastContext';

const Breeds = () => {
  const { showToast } = useToast();
  const [breeds, setBreeds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentBreed, setCurrentBreed] = useState({ breed_id: '', name: '' });
  const [isEditing, setIsEditing] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;
  const [searchTerm, setSearchTerm] = useState('');
  const [sortOrder, setSortOrder] = useState('newest');

  useEffect(() => {
    fetchBreeds();
  }, []);

  const fetchBreeds = async () => {
    try {
      const response = await api.get('/breeds');
      setBreeds(response.data.data || response.data);
      setCurrentPage(1);
    } catch (error) {
      console.error("Error fetching breeds:", error);
      showToast("ไม่สามารถดึงข้อมูลสายพันธุ์ได้", "error");
    } finally {
      setLoading(false);
    }
  };

  const getNextId = () => {
    let max = 0;
    breeds.forEach(b => {
      const match = (b.breed_id || '').match(/(\d+)/);
      if (match) {
        const num = parseInt(match[1], 10);
        if (num > max) max = num;
      }
    });
    return 'B' + String(max + 1).padStart(3, '0');
  };

  const handleOpenModal = (breed = null) => {
    if (breed) {
      setCurrentBreed(breed);
      setIsEditing(true);
    } else {
      setCurrentBreed({ breed_id: getNextId(), name: '' });
      setIsEditing(false);
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setCurrentBreed({ breed_id: '', name: '' });
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
        showToast(`แก้ไขข้อมูลสายพันธุ์ "${currentBreed.name}" สำเร็จ`, "success");
      } else {
        await api.post('/breeds', currentBreed);
        showToast(`เพิ่มสายพันธุ์ใหม่ "${currentBreed.name}" สำเร็จ`, "success");
      }
      fetchBreeds();
      handleCloseModal();
    } catch (error) {
      console.error("Error saving breed:", error);
      showToast("เกิดข้อผิดพลาดในการบันทึกข้อมูลสายพันธุ์", "error");
    }
  };

  const handleDelete = async (id, name = '') => {
    if (window.confirm(`คุณแน่ใจหรือไม่ว่าต้องการลบสายพันธุ์ "${name || id}"?`)) {
      try {
        await api.delete(`/breeds/${id}`);
        showToast(`ลบสายพันธุ์ "${name || id}" เรียบร้อยแล้ว`, "info");
        fetchBreeds();
      } catch (error) {
        console.error("Error deleting breed:", error);
        showToast("เกิดข้อผิดพลาดในการลบข้อมูลสายพันธุ์", "error");
      }
    }
  };

  const filteredAndSorted = breeds
    .filter(b => 
      (b.name || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
      (b.breed_id || '').toLowerCase().includes(searchTerm.toLowerCase())
    )
    .sort((a, b) => {
      const compare = (b.breed_id || '').localeCompare(a.breed_id || '');
      return sortOrder === 'newest' ? compare : -compare;
    });

  const totalPages = Math.ceil(filteredAndSorted.length / itemsPerPage) || 1;
  const currentItems = filteredAndSorted.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

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
                    <th style={{ width: '220px' }}>รหัสสายพันธุ์</th>
                    <th>ชื่อสายพันธุ์</th>
                    <th style={{ width: '120px', textAlign: 'right', paddingRight: '24px' }}>จัดการ</th>
                  </tr>
                </thead>
                <tbody>
                  {currentItems.length > 0 ? (
                    currentItems.map((breed) => (
                      <tr key={breed.breed_id}>
                        <td>{breed.breed_id}</td>
                        <td style={{ fontWeight: '500' }}>{breed.name}</td>
                        <td style={{ textAlign: 'right' }}>
                          <div className="action-links" style={{ justifyContent: 'flex-end', paddingRight: '4px' }}>
                            <button className="action-btn edit" onClick={() => handleOpenModal(breed)}>
                              <Edit size={16} />
                            </button>
                            <button className="action-btn delete" onClick={() => handleDelete(breed.breed_id, breed.name)}>
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
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '500px' }}>
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
                    disabled={isEditing}
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
