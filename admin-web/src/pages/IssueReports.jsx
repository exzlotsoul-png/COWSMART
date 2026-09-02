import React, { useState, useEffect } from 'react';
import { 
  CheckCircle, Trash2, Search, ArrowUpDown, Image as ImageIcon, 
  Tag, Plus, Edit, X, AlertCircle, CheckCircle2, Eye, Calendar,
  User, MessageSquare, Clock, Check
} from 'lucide-react';
import api from '../lib/axios';
import Pagination from '../components/layout/Pagination';
import { useToast } from '../contexts/ToastContext';

const IssueReports = () => {
  const { showToast } = useToast();
  const [reports, setReports] = useState([]);
  const [topics, setTopics] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [sortOrder, setSortOrder] = useState('newest');
  const [typeFilter, setTypeFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [loading, setLoading] = useState(true);
  const [currentPage, setCurrentPage] = useState(1);
  const [selectedReportDetail, setSelectedReportDetail] = useState(null);
  const [selectedImage, setSelectedImage] = useState(null);
  const itemsPerPage = 10;

  // Topic Management State
  const [isTopicModalOpen, setIsTopicModalOpen] = useState(false);
  const [editingTopic, setEditingTopic] = useState(null);
  const [topicNameInput, setTopicNameInput] = useState('');
  const [isSavingTopic, setIsSavingTopic] = useState(false);
  const [topicDeleteConfirm, setTopicDeleteConfirm] = useState(null);

  useEffect(() => {
    fetchReports();
    fetchTopics();
  }, []);

  const showNotification = (text, type = 'success') => {
    showToast(text, type);
  };

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

  const fetchTopics = async () => {
    try {
      const response = await api.get('/report_topics');
      setTopics(response.data || []);
    } catch (error) {
      console.error("Error fetching report topics:", error);
    }
  };

  const handleResolve = async (id, currentStatus) => {
    const isResolved = currentStatus === 1 || currentStatus === '1' || currentStatus === 'resolved';
    const nextStatus = isResolved ? 0 : 1;
    try {
      await api.put(`/issue_reports/${id}`, { status: nextStatus });
      await fetchReports();
      if (selectedReportDetail && (selectedReportDetail.id === id || selectedReportDetail.report_id === id)) {
        setSelectedReportDetail(prev => prev ? { ...prev, status: nextStatus } : null);
      }
      showNotification(nextStatus === 1 ? 'เปลี่ยนสถานะเป็นแก้ไขแล้ว' : 'เปลี่ยนสถานะเป็นรอดำเนินการ');
    } catch (error) {
      console.error("Error updating report:", error);
      showNotification("เกิดข้อผิดพลาดในการอัปเดตสถานะ", "error");
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("คุณแน่ใจหรือไม่ว่าต้องการลบรายงานนี้?")) {
      try {
        await api.delete(`/issue_reports/${id}`);
        fetchReports();
        if (selectedReportDetail && (selectedReportDetail.id === id || selectedReportDetail.report_id === id)) {
          setSelectedReportDetail(null);
        }
        showNotification("ลบรายงานเรียบร้อยแล้ว");
      } catch (error) {
        console.error("Error deleting report:", error);
        showNotification("เกิดข้อผิดพลาดในการลบข้อมูล", "error");
      }
    }
  };

  // ── TOPIC CRUD HANDLERS ──
  const handleOpenTopicModal = () => {
    setEditingTopic(null);
    setTopicNameInput('');
    setTopicDeleteConfirm(null);
    setIsTopicModalOpen(true);
  };

  const handleEditTopicClick = (topic) => {
    setEditingTopic(topic);
    setTopicNameInput(topic.name);
  };

  const handleCancelEditTopic = () => {
    setEditingTopic(null);
    setTopicNameInput('');
  };

  const handleSaveTopic = async (e) => {
    e.preventDefault();
    if (!topicNameInput.trim()) return;

    setIsSavingTopic(true);
    try {
      if (editingTopic) {
        // Update existing topic
        await api.put(`/report_topics/${editingTopic.id}`, { name: topicNameInput.trim() });
        showNotification(`แก้ไขหัวข้อ "${topicNameInput.trim()}" สำเร็จ`);
      } else {
        // Create new topic
        await api.post('/report_topics', { name: topicNameInput.trim() });
        showNotification(`เพิ่มหัวข้อ "${topicNameInput.trim()}" สำเร็จ`);
      }
      setTopicNameInput('');
      setEditingTopic(null);
      await fetchTopics();
    } catch (error) {
      console.error("Error saving topic:", error);
      showNotification("เกิดข้อผิดพลาดในการบันทึกหัวข้อ", "error");
    } finally {
      setIsSavingTopic(false);
    }
  };

  const handleDeleteTopic = async (topicId) => {
    try {
      await api.delete(`/report_topics/${topicId}`);
      showNotification("ลบหัวข้อรายงานเรียบร้อยแล้ว");
      setTopicDeleteConfirm(null);
      await fetchTopics();
    } catch (error) {
      console.error("Error deleting topic:", error);
      showNotification("เกิดข้อผิดพลาดในการลบหัวข้อ", "error");
    }
  };

  // Filter options strictly based on actual topics registered in DB
  const filterTopicOptions = topics.map(t => t.name);

  const filteredAndSorted = reports
    .filter(item => {
      const id = String(item.id || item.report_id || '');
      const email = String(item.email || item.user_id || '');
      const topic = String(item.topic || item.issue_type || '');
      const desc = String(item.description || '');
      const statusText = (item.status === 1 || item.status === '1' || item.status === 'resolved') ? 'แก้ไขแล้ว' : 'รอดำเนินการ';
      const dateText = item.created_at ? new Date(item.created_at).toLocaleDateString('th-TH') : '';

      const matchSearch = 
        topic.toLowerCase().includes(searchTerm.toLowerCase()) || 
        desc.toLowerCase().includes(searchTerm.toLowerCase()) || 
        email.toLowerCase().includes(searchTerm.toLowerCase()) || 
        statusText.toLowerCase().includes(searchTerm.toLowerCase()) || 
        dateText.includes(searchTerm) ||
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
      const dateA = a.created_at ? new Date(a.created_at).getTime() : 0;
      const dateB = b.created_at ? new Date(b.created_at).getTime() : 0;
      if (dateA && dateB && dateA !== dateB) {
        return sortOrder === 'newest' ? dateB - dateA : dateA - dateB;
      }
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
        <div className="card-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
          <div>
            <h2 className="card-title">จัดการรายงานการใช้งาน</h2>
            <p style={{ margin: '4px 0 0 0', fontSize: '0.85rem', color: 'var(--text-muted)' }}>
              รายการแจ้งปัญหาและข้อเสนอแนะจากผู้ใช้งานแอปพลิเคชัน
            </p>
          </div>
          <button 
            className="btn btn-primary"
            style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
            onClick={handleOpenTopicModal}
          >
            <Tag size={18} />
            จัดการหัวข้อปัญหา
          </button>
        </div>

        {/* Filters Toolbar */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 24px', flexWrap: 'wrap', gap: '16px' }}>
          <div style={{ display: 'flex', gap: '12px', flexGrow: 1, maxWidth: '700px', flexWrap: 'wrap' }}>
            <div className="search-box" style={{ display: 'flex', alignItems: 'center', backgroundColor: '#f3f4f6', padding: '8px 12px', borderRadius: '8px', width: '250px', flexGrow: 1, maxWidth: '350px' }}>
              <Search size={18} style={{ color: '#9ca3af', marginRight: '8px' }} />
              <input 
                type="text" 
                placeholder="ค้นหา (รหัส, อีเมล, หัวข้อ, วันที่)..." 
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
              {filterTopicOptions.map(t => (
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
                    <th style={{ width: '100px' }}>รหัสรายงาน</th>
                    <th style={{ width: '120px' }}>วันที่รายงาน</th>
                    <th style={{ minWidth: '160px' }}>ผู้ใช้งาน (อีเมล)</th>
                    <th style={{ minWidth: '160px' }}>หัวข้อปัญหา</th>
                    <th style={{ maxWidth: '200px' }}>รายละเอียด</th>
                    <th style={{ width: '120px', whiteSpace: 'nowrap' }}>สถานะ</th>
                    <th style={{ width: '110px', textAlign: 'center', whiteSpace: 'nowrap' }}>จัดการ</th>
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
                          <td style={{ fontWeight: '600' }}>
                            <button
                              onClick={() => setSelectedReportDetail(report)}
                              style={{
                                background: 'none',
                                border: 'none',
                                color: 'var(--primary-color)',
                                fontWeight: '700',
                                cursor: 'pointer',
                                padding: 0,
                                fontSize: '0.875rem'
                              }}
                              title="คลิกเพื่อดูรายละเอียด"
                            >
                              {id}
                            </button>
                          </td>
                          <td style={{ color: '#111827', whiteSpace: 'nowrap', fontSize: '0.85rem' }}>
                            {report.created_at ? (
                              <>
                                <div style={{ fontWeight: '500' }}>{new Date(report.created_at).toLocaleDateString('th-TH')}</div>
                                <div style={{ fontSize: '0.75rem', color: '#6b7280' }}>
                                  {new Date(report.created_at).toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit' })}
                                </div>
                              </>
                            ) : '-'}
                          </td>
                          <td style={{ wordBreak: 'break-all' }}>{email}</td>
                          <td style={{ fontWeight: '500' }}>{topic}</td>
                          <td style={{ maxWidth: '200px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }} title={report.description}>
                            {report.description || '-'}
                          </td>
                          <td style={{ whiteSpace: 'nowrap' }}>
                            <span style={{ 
                              display: 'inline-block',
                              whiteSpace: 'nowrap',
                              padding: '4px 12px', 
                              borderRadius: '12px', 
                              fontSize: '0.82rem',
                              fontWeight: '700',
                              backgroundColor: isResolved ? 'var(--primary-light)' : '#fee2e2',
                              color: isResolved ? 'var(--primary-color)' : '#991b1b'
                            }}>
                              {isResolved ? 'แก้ไขแล้ว' : 'รอดำเนินการ'}
                            </span>
                          </td>
                          <td>
                            <div className="action-links" style={{ justifyContent: 'center' }}>
                              <button 
                                className="action-btn"
                                onClick={() => setSelectedReportDetail(report)}
                                title="ดูรายละเอียดรายงาน"
                                style={{ color: '#2563eb' }}
                              >
                                <Eye size={16} />
                              </button>
                              <button 
                                className="action-btn" 
                                style={{ color: isResolved ? '#9ca3af' : 'var(--primary-color)' }}
                                onClick={() => handleResolve(id, report.status)}
                                title={isResolved ? "ทำเป็นรอดำเนินการ" : "ทำเป็นแก้ไขแล้ว"}
                              >
                                <CheckCircle size={16} />
                              </button>
                              <button className="action-btn delete" onClick={() => handleDelete(id)} title="ลบรายงาน">
                                <Trash2 size={16} />
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })
                  ) : (
                    <tr>
                      <td colSpan="7" style={{ textAlign: 'center', padding: '24px', color: 'var(--text-muted)' }}>
                        ไม่พบข้อมูลรายงานปัญหา
                      </td>
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

      {/* ── MODAL: REPORT DETAIL (ดูรายละเอียดรายงาน) ── */}
      {selectedReportDetail && (
        <div className="modal-overlay" onClick={() => setSelectedReportDetail(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '640px', width: '100%' }}>
            <div className="modal-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <MessageSquare size={20} color="var(--primary-color)" />
                <h3 className="modal-title">รายละเอียดรายงานการใช้งาน</h3>
                <span style={{ 
                  backgroundColor: 'var(--primary-light)', 
                  color: 'var(--primary-color)', 
                  padding: '2px 8px', 
                  borderRadius: '6px', 
                  fontSize: '0.8rem', 
                  fontWeight: '700' 
                }}>
                  {selectedReportDetail.id || selectedReportDetail.report_id}
                </span>
              </div>
              <button className="modal-close" onClick={() => setSelectedReportDetail(null)}>&times;</button>
            </div>

            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {/* Top Info Grid */}
              <div style={{ 
                display: 'grid', 
                gridTemplateColumns: '1fr 1fr', 
                gap: '12px',
                backgroundColor: '#f8fafc',
                padding: '14px',
                borderRadius: '10px',
                border: '1px solid #e2e8f0'
              }}>
                <div>
                  <span style={{ fontSize: '0.75rem', color: '#64748b', display: 'flex', alignItems: 'center', gap: '4px', marginBottom: '2px' }}>
                    <Calendar size={13} /> วันที่และเวลาที่แจ้ง
                  </span>
                  <div style={{ fontWeight: '600', color: '#1e293b', fontSize: '0.9rem' }}>
                    {selectedReportDetail.created_at ? (
                      `${new Date(selectedReportDetail.created_at).toLocaleDateString('th-TH')} เวลา ${new Date(selectedReportDetail.created_at).toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit' })}`
                    ) : '-'}
                  </div>
                </div>

                <div>
                  <span style={{ fontSize: '0.75rem', color: '#64748b', display: 'flex', alignItems: 'center', gap: '4px', marginBottom: '2px' }}>
                    <User size={13} /> ผู้ใช้งาน (อีเมล)
                  </span>
                  <div style={{ fontWeight: '600', color: '#1e293b', fontSize: '0.9rem', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {selectedReportDetail.email || selectedReportDetail.user_id || '-'}
                  </div>
                </div>

                <div>
                  <span style={{ fontSize: '0.75rem', color: '#64748b', display: 'flex', alignItems: 'center', gap: '4px', marginBottom: '2px' }}>
                    <Tag size={13} /> หัวข้อปัญหา
                  </span>
                  <div style={{ fontWeight: '600', color: 'var(--primary-color)', fontSize: '0.9rem' }}>
                    {selectedReportDetail.topic || selectedReportDetail.issue_type || '-'}
                  </div>
                </div>

                <div>
                  <span style={{ fontSize: '0.75rem', color: '#64748b', display: 'flex', alignItems: 'center', gap: '4px', marginBottom: '2px' }}>
                    <Clock size={13} /> สถานะดำเนินการ
                  </span>
                  <div>
                    {selectedReportDetail.status === 1 || selectedReportDetail.status === '1' || selectedReportDetail.status === 'resolved' ? (
                      <span style={{ backgroundColor: 'var(--primary-light)', color: 'var(--primary-color)', padding: '3px 8px', borderRadius: '8px', fontSize: '0.8rem', fontWeight: '700' }}>
                        แก้ไขแล้ว
                      </span>
                    ) : (
                      <span style={{ backgroundColor: '#fee2e2', color: '#991b1b', padding: '3px 8px', borderRadius: '8px', fontSize: '0.8rem', fontWeight: '700' }}>
                        รอดำเนินการ
                      </span>
                    )}
                  </div>
                </div>
              </div>

              {/* Description Section */}
              <div>
                <label style={{ fontSize: '0.85rem', fontWeight: '600', color: '#334155', display: 'block', marginBottom: '6px' }}>
                  รายละเอียดปัญหา / ข้อเสนอแนะ:
                </label>
                <div style={{ 
                  backgroundColor: '#fff', 
                  border: '1px solid #cbd5e1', 
                  borderRadius: '8px', 
                  padding: '12px 14px', 
                  fontSize: '0.9rem',
                  lineHeight: '1.6',
                  color: '#1e293b',
                  whiteSpace: 'pre-wrap',
                  minHeight: '80px'
                }}>
                  {selectedReportDetail.description || 'ไม่มีรายละเอียดเพิ่มเติม'}
                </div>
              </div>

              {/* Attached Image Section */}
              <div>
                <label style={{ fontSize: '0.85rem', fontWeight: '600', color: '#334155', display: 'block', marginBottom: '6px' }}>
                  รูปภาพประกอบรายงาน:
                </label>
                {selectedReportDetail.image_url ? (
                  <div style={{ textAlign: 'center', backgroundColor: '#f8fafc', padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
                    <img 
                      src={formatImageUrl(selectedReportDetail.image_url)} 
                      alt="Report Attachment" 
                      onClick={() => setSelectedImage(formatImageUrl(selectedReportDetail.image_url))}
                      style={{ 
                        maxWidth: '100%', 
                        maxHeight: '260px', 
                        borderRadius: '8px', 
                        cursor: 'pointer',
                        boxShadow: '0 2px 6px rgba(0,0,0,0.1)'
                      }} 
                      title="คลิกเพื่อขยายรูปภาพ"
                    />
                    <div style={{ fontSize: '0.75rem', color: '#64748b', marginTop: '6px' }}>
                      (คลิกที่รูปเพื่อดูภาพขนาดเต็ม)
                    </div>
                  </div>
                ) : (
                  <div style={{ 
                    padding: '16px', 
                    textAlign: 'center', 
                    color: '#94a3b8', 
                    backgroundColor: '#f8fafc', 
                    borderRadius: '8px', 
                    border: '1px dashed #cbd5e1',
                    fontSize: '0.85rem'
                  }}>
                    ไม่มีรูปภาพแนบในรายงานนี้
                  </div>
                )}
              </div>
            </div>

            <div className="modal-footer" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <button
                  type="button"
                  className="btn"
                  onClick={() => handleResolve(selectedReportDetail.id || selectedReportDetail.report_id, selectedReportDetail.status)}
                  style={{
                    backgroundColor: (selectedReportDetail.status === 1 || selectedReportDetail.status === '1' || selectedReportDetail.status === 'resolved') ? '#f3f4f6' : '#10b981',
                    color: (selectedReportDetail.status === 1 || selectedReportDetail.status === '1' || selectedReportDetail.status === 'resolved') ? '#374151' : '#fff',
                    border: '1px solid ' + ((selectedReportDetail.status === 1 || selectedReportDetail.status === '1' || selectedReportDetail.status === 'resolved') ? '#d1d5db' : '#10b981'),
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px'
                  }}
                >
                  <CheckCircle size={16} />
                  {(selectedReportDetail.status === 1 || selectedReportDetail.status === '1' || selectedReportDetail.status === 'resolved') ? 'เปลี่ยนเป็นรอดำเนินการ' : 'ทำเครื่องหมายว่าแก้ไขแล้ว'}
                </button>
              </div>

              <div style={{ display: 'flex', gap: '8px' }}>
                <button 
                  type="button" 
                  className="btn btn-outline" 
                  onClick={() => setSelectedReportDetail(null)}
                >
                  ปิด
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── MODAL: MANAGE REPORT TOPICS ── */}
      {isTopicModalOpen && (
        <div className="modal-overlay" onClick={() => setIsTopicModalOpen(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '640px', width: '100%' }}>
            <div className="modal-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Tag size={20} color="var(--primary-color)" />
                <h3 className="modal-title">จัดการหัวข้อรายงาน / ปัญหา</h3>
              </div>
              <button className="modal-close" onClick={() => setIsTopicModalOpen(false)}>&times;</button>
            </div>

            <div className="modal-body">
              {/* Add / Edit Input Form */}
              <form onSubmit={handleSaveTopic} style={{ marginBottom: '20px' }}>
                <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                  <input
                    type="text"
                    placeholder="พิมพ์ชื่อหัวข้อปัญหาใหม่ เช่น ปัญหาการบันทึกข้อมูล..."
                    value={topicNameInput}
                    onChange={(e) => setTopicNameInput(e.target.value)}
                    style={{
                      flex: 1,
                      padding: '10px 14px',
                      borderRadius: '8px',
                      border: '1px solid var(--border-color)',
                      fontSize: '0.9rem',
                      outline: 'none'
                    }}
                    required
                  />
                  <button 
                    type="submit" 
                    className="btn btn-primary"
                    disabled={isSavingTopic || !topicNameInput.trim()}
                    style={{ display: 'flex', alignItems: 'center', gap: '6px', whiteSpace: 'nowrap' }}
                  >
                    {editingTopic ? <Edit size={16} /> : <Plus size={16} />}
                    {isSavingTopic ? 'กำลังบันทึก...' : (editingTopic ? 'อัปเดต' : 'เพิ่มหัวข้อ')}
                  </button>
                  {editingTopic && (
                    <button 
                      type="button" 
                      className="btn btn-outline"
                      onClick={handleCancelEditTopic}
                    >
                      ยกเลิก
                    </button>
                  )}
                </div>
                {editingTopic && (
                  <div style={{ fontSize: '0.8rem', color: 'var(--primary-color)', marginTop: '6px' }}>
                    กำลังแก้ไขรหัส: <strong>{editingTopic.id}</strong>
                  </div>
                )}
              </form>

              {/* Topics Table */}
              <div style={{ maxHeight: '350px', overflowY: 'auto', border: '1px solid var(--border-color)', borderRadius: '8px' }}>
                <table className="data-table" style={{ margin: 0 }}>
                  <thead style={{ position: 'sticky', top: 0, zIndex: 1, backgroundColor: '#f9fafb' }}>
                    <tr>
                      <th style={{ width: '110px' }}>รหัส</th>
                      <th>ชื่อหัวข้อรายงาน</th>
                      <th style={{ width: '90px', textAlign: 'center' }}>จัดการ</th>
                    </tr>
                  </thead>
                  <tbody>
                    {topics.length > 0 ? (
                      topics.map((t) => (
                        <tr key={t.id}>
                          <td style={{ fontWeight: '600', color: 'var(--text-muted)' }}>{t.id}</td>
                          <td style={{ fontWeight: '500', color: '#111827' }}>{t.name}</td>
                          <td>
                            <div className="action-links" style={{ justifyContent: 'center' }}>
                              <button 
                                className="action-btn"
                                onClick={() => handleEditTopicClick(t)}
                                title="แก้ไขชื่อหัวข้อ"
                                style={{ color: '#2563eb' }}
                              >
                                <Edit size={16} />
                              </button>
                              <button 
                                className="action-btn delete"
                                onClick={() => setTopicDeleteConfirm(t)}
                                title="ลบหัวข้อ"
                              >
                                <Trash2 size={16} />
                              </button>
                            </div>
                          </td>
                        </tr>
                      ))
                    ) : (
                      <tr>
                        <td colSpan="3" style={{ textAlign: 'center', padding: '20px', color: 'var(--text-muted)' }}>
                          ยังไม่มีข้อมูลหัวข้อรายงานในระบบ
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <button 
                type="button" 
                className="btn btn-outline" 
                onClick={() => setIsTopicModalOpen(false)}
              >
                ปิดหน้าต่าง
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Topic Confirmation Modal */}
      {topicDeleteConfirm && (
        <div className="modal-overlay" onClick={() => setTopicDeleteConfirm(null)} style={{ zIndex: 1100 }}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '420px', textAlign: 'center' }}>
            <div style={{ padding: '24px 20px' }}>
              <div style={{ 
                width: '52px', 
                height: '52px', 
                borderRadius: '50%', 
                backgroundColor: '#fee2e2', 
                color: '#dc2626', 
                display: 'flex', 
                alignItems: 'center', 
                justifyContent: 'center', 
                margin: '0 auto 16px auto' 
              }}>
                <Trash2 size={26} />
              </div>
              <h3 style={{ fontSize: '1.2rem', fontWeight: 'bold', margin: '0 0 8px 0', color: '#111827' }}>
                ยืนยันการลบหัวข้อ
              </h3>
              <p style={{ fontSize: '0.9rem', color: '#6b7280', margin: '0 0 20px 0' }}>
                คุณต้องการลบหัวข้อ <strong>"{topicDeleteConfirm.name}"</strong> ({topicDeleteConfirm.id}) หรือไม่?
              </p>
              <div style={{ display: 'flex', gap: '10px', justifyContent: 'center' }}>
                <button 
                  className="btn btn-outline" 
                  onClick={() => setTopicDeleteConfirm(null)}
                  style={{ flex: 1 }}
                >
                  ยกเลิก
                </button>
                <button 
                  className="btn" 
                  onClick={() => handleDeleteTopic(topicDeleteConfirm.id)}
                  style={{ flex: 1, backgroundColor: '#dc2626', color: '#fff', border: 'none' }}
                >
                  ยืนยันการลบ
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Full Image Zoom Modal */}
      {selectedImage && (
        <div className="modal-overlay" onClick={() => setSelectedImage(null)} style={{ zIndex: 1200 }}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '650px', textAlign: 'center' }}>
            <div className="modal-header">
              <h3 className="modal-title">รูปภาพประกอบรายงาน (ขนาดเต็ม)</h3>
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
