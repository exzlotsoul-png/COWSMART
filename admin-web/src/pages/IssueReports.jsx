import React, { useState, useEffect } from 'react';
import { CheckCircle, Trash2, Search, ArrowUpDown, Image as ImageIcon } from 'lucide-react';
import api from '../lib/axios';
import Pagination from '../components/layout/Pagination';

const IssueReports = () => {
  const [reports, setReports] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [sortOrder, setSortOrder] = useState('newest');
  const [typeFilter, setTypeFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [loading, setLoading] = useState(true);
  const [currentPage, setCurrentPage] = useState(1);
  const [selectedImage, setSelectedImage] = useState(null);
  const itemsPerPage = 10;

  useEffect(() => {
    fetchReports();
  }, []);

  const fetchReports = async () => {
    try {
      const response = await api.get('/issue_reports');
      setReports(response.data.data || response.data || []);
      setCurrentPage(1);
    } catch (error) {
      console.error("Error fetching reports:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleResolve = async (id, currentStatus) => {
    const isResolved = currentStatus === 1 || currentStatus === '1' || currentStatus === 'resolved';
    const nextStatus = isResolved ? 0 : 1;
    try {
      await api.put(`/issue_reports/${id}`, { status: nextStatus });
      fetchReports();
    } catch (error) {
      console.error("Error updating report:", error);
      alert("เกิดข้อผิดพลาดในการอัปเดตสถานะ");
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("คุณแน่ใจหรือไม่ว่าต้องการลบรายงานนี้?")) {
      try {
        await api.delete(`/issue_reports/${id}`);
        fetchReports();
      } catch (error) {
        console.error("Error deleting report:", error);
        alert("เกิดข้อผิดพลาดในการลบข้อมูล");
      }
    }
  };

  const uniqueTypes = Array.from(new Set(reports.map(r => r.topic || r.issue_type).filter(Boolean)));

  const filteredAndSorted = reports
    .filter(item => {
      const id = String(item.id || item.report_id || '');
      const email = String(item.email || item.user_id || '');
      const topic = String(item.topic || item.issue_type || '');
      const desc = String(item.description || '');
      const statusText = (item.status === 1 || item.status === '1' || item.status === 'resolved') ? 'แก้ไขแล้ว' : 'รอดำเนินการ';

      const matchSearch = 
        topic.toLowerCase().includes(searchTerm.toLowerCase()) || 
        desc.toLowerCase().includes(searchTerm.toLowerCase()) || 
        email.toLowerCase().includes(searchTerm.toLowerCase()) || 
        statusText.toLowerCase().includes(searchTerm.toLowerCase()) || 
        id.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchType = typeFilter === 'all' || topic === typeFilter;
      
      let matchStatus = true;
      if (statusFilter === 'pending') {
        matchStatus = (item.status === 0 || item.status === '0' || item.status === 'pending');
      } else if (statusFilter === 'resolved') {
        matchStatus = (item.status === 1 || item.status === '1' || item.status === 'resolved');
      }

      return matchSearch && matchType && matchStatus;
    })
    .sort((a, b) => {
      const idA = String(a.id || a.report_id || '');
      const idB = String(b.id || b.report_id || '');
      const compare = idB.localeCompare(idA);
      return sortOrder === 'newest' ? compare : -compare;
    });

  const totalItems = filteredAndSorted.length;
  const totalPages = Math.ceil(totalItems / itemsPerPage) || 1;
  const currentReports = filteredAndSorted.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const formatImageUrl = (url) => {
    if (!url) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return `http://127.0.0.1:8000/api/storage/${url.replace(/^\/?storage\//, '')}`;
  };

  return (
    <div>
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">จัดการรายงานการใช้งาน</h2>
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
                onChange={(e) => { setSearchTerm(e.target.value); setCurrentPage(1); }}
              />
            </div>
            
            <select
              value={typeFilter}
              onChange={(e) => { setTypeFilter(e.target.value); setCurrentPage(1); }}
              style={{ padding: '8px 12px', borderRadius: '8px', border: '1px solid var(--border-color)', backgroundColor: '#fff', color: 'var(--text-main)', fontSize: '0.875rem' }}
            >
              <option value="all">ทุกประเภทปัญหา</option>
              {uniqueTypes.map(t => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>

            <select
              value={statusFilter}
              onChange={(e) => { setStatusFilter(e.target.value); setCurrentPage(1); }}
              style={{ padding: '8px 12px', borderRadius: '8px', border: '1px solid var(--border-color)', backgroundColor: '#fff', color: 'var(--text-main)', fontSize: '0.875rem' }}
            >
              <option value="all">ทุกสถานะ</option>
              <option value="pending">รอดำเนินการ</option>
              <option value="resolved">แก้ไขแล้ว</option>
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
          <p style={{ padding: '24px' }}>กำลังโหลดข้อมูล...</p>
        ) : (
          <>
            <div className="table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>รหัสรายงาน</th>
                    <th>ผู้ใช้งาน (อีเมล)</th>
                    <th>หัวข้อปัญหา</th>
                    <th>รายละเอียด</th>
                    <th>รูปภาพ</th>
                    <th>สถานะ</th>
                    <th>จัดการ</th>
                  </tr>
                </thead>
                <tbody>
                  {currentReports.length > 0 ? (
                    currentReports.map((report) => {
                      const id = report.id || report.report_id;
                      const email = report.email || report.user_id || '-';
                      const topic = report.topic || report.issue_type || '-';
                      const isResolved = report.status === 1 || report.status === '1' || report.status === 'resolved';

                      return (
                        <tr key={id}>
                          <td>{id}</td>
                          <td>{email}</td>
                          <td>{topic}</td>
                          <td style={{ maxWidth: '280px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }} title={report.description}>
                            {report.description || '-'}
                          </td>
                          <td>
                            {report.image_url ? (
                              <button 
                                className="action-btn"
                                onClick={() => setSelectedImage(formatImageUrl(report.image_url))}
                                title="ดูรูปภาพแนบ"
                                style={{ color: '#2563eb' }}
                              >
                                <ImageIcon size={18} />
                              </button>
                            ) : '-'}
                          </td>
                          <td>
                            <span style={{ 
                              padding: '4px 8px', 
                              borderRadius: '12px', 
                              fontSize: '0.85rem',
                              backgroundColor: isResolved ? '#d1fae5' : '#fee2e2',
                              color: isResolved ? '#065f46' : '#991b1b'
                            }}>
                              {isResolved ? 'แก้ไขแล้ว' : 'รอดำเนินการ'}
                            </span>
                          </td>
                          <td>
                            <div className="action-links">
                              <button 
                                className="action-btn" 
                                style={{ color: isResolved ? '#9ca3af' : '#10b981' }}
                                onClick={() => handleResolve(id, report.status)}
                                title={isResolved ? "ทำเป็นรอดำเนินการ" : "ทำเป็นแก้ไขแล้ว"}
                              >
                                <CheckCircle size={16} />
                              </button>
                              <button className="action-btn delete" onClick={() => handleDelete(id)}>
                                <Trash2 size={16} />
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })
                  ) : (
                    <tr>
                      <td colSpan="7" style={{ textAlign: 'center' }}>ไม่พบข้อมูลรายงานปัญหา</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            <Pagination
              currentPage={currentPage}
              totalPages={totalPages}
              onPageChange={setCurrentPage}
              totalItems={totalItems}
              itemsPerPage={itemsPerPage}
            />
          </>
        )}
      </div>

      {selectedImage && (
        <div className="modal-overlay" onClick={() => setSelectedImage(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '600px', textAlign: 'center' }}>
            <div className="modal-header">
              <h3 className="modal-title">รูปภาพประกอบรายงาน</h3>
              <button className="modal-close" onClick={() => setSelectedImage(null)}>&times;</button>
            </div>
            <div className="modal-body">
              <img src={selectedImage} alt="Report Attachment" style={{ maxWidth: '100%', maxHeight: '70vh', borderRadius: '8px' }} />
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default IssueReports;
