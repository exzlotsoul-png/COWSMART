import React, { useState, useEffect } from 'react';
import { CheckCircle, Trash2, Search, ArrowUpDown } from 'lucide-react';
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
  const itemsPerPage = 10;

  // Mock data as fallback when api doesn't return anything or is empty
  const mockReports = [
    {
      report_id: 1,
      user_id: "somchai@gmail.com",
      issue_type: "ปัญหาการใช้งานแอปพลิเคชัน",
      description: "กดบันทึกน้ำนมดิบแล้วระบบหมุนค้างและขึ้น Error 500 ครับ ลองรีสตาร์ตเครื่องแล้วก็ยังบันทึกไม่ได้",
      status: "resolved"
    },
    {
      report_id: 2,
      user_id: "somying@farm.com",
      issue_type: "ข้อเสนอแนะ",
      description: "อยากให้เพิ่มปุ่มส่งออกข้อมูลประวัติการรักษาของวัวเป็นไฟล์ PDF เพื่อพิมพ์ใช้งานในฟาร์มและส่งรายงานง่ายขึ้น",
      status: "resolved"
    },
    {
      report_id: 3,
      user_id: "wichai@cowsmart.com",
      issue_type: "ปัญหาอุปกรณ์ฮาร์ดแวร์",
      description: "สแกน RFID แท็กหูวัวแล้วใช้เวลาโหลด 5-10 วินาที กว่าจะขึ้นข้อมูลในหน้าจอแอปมือถือ",
      status: "pending"
    },
    {
      report_id: 4,
      user_id: "kitti@cowland.com",
      issue_type: "บัญชีผู้ใช้",
      description: "ตอนนี้ใช้แพ็กเกจฟรีอยู่ ต้องการเพิ่มฟาร์มที่สองต้องทำอย่างไรบ้างครับ มีโปรโมชั่นช่วงนี้ไหม",
      status: "pending"
    },
    {
      report_id: 5,
      user_id: "napa@sunsetfarm.com",
      issue_type: "ปัญหาการใช้งานแอปพลิเคชัน",
      description: "เพิ่มรูปโปรไฟล์วัวไม่ได้ค่ะ พอกดอัปโหลดแล้วแอปค้างเด้งออกทันที ใช้ iOS 17.4 ค่ะ",
      status: "pending"
    },
    {
      report_id: 6,
      user_id: "mana@cowsmart.com",
      issue_type: "ข้อเสนอแนะ",
      description: "อยากให้สามารถกรองสถิติน้ำนมดิบรายสัปดาห์ได้ด้วยครับ ปัจจุบันมีแค่รายวันและรายเดือน",
      status: "pending"
    },
    {
      report_id: 7,
      user_id: "sudarat@greenhill.com",
      issue_type: "ปัญหาการใช้งานแอปพลิเคชัน",
      description: "ไม่สามารถสืบค้นประวัติวัคซีนย้อนหลังเกิน 1 ปีได้ค่ะ หน้าเว็บไม่โหลดผลลัพธ์",
      status: "pending"
    }
  ];

  useEffect(() => {
    fetchReports();
  }, []);

  const fetchReports = async () => {
    try {
      const response = await api.get('/issue_reports');
      setReports(response.data.data || response.data);
      setCurrentPage(1);
    } catch (error) {
      console.error("Error fetching reports:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleResolve = async (id, currentStatus) => {
    const newStatus = currentStatus === 'resolved' ? 'pending' : 'resolved';
    try {
      // If it's mock data (id is in mock list & real list is empty), handle it statefully
      if (reports.length === 0) {
        // Toggle in mock
        const updated = reportsToDisplay.map(r => r.report_id === id ? { ...r, status: newStatus } : r);
        setReports(updated);
        return;
      }
      await api.put(`/issue_reports/${id}`, { status: newStatus });
      fetchReports();
    } catch (error) {
      console.error("Error updating report:", error);
      alert("เกิดข้อผิดพลาดในการอัปเดตสถานะ");
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("คุณแน่ใจหรือไม่ว่าต้องการลบรายงานนี้?")) {
      try {
        if (reports.length === 0) {
          // Remove from mock list
          setReports(reportsToDisplay.filter(r => r.report_id !== id));
          return;
        }
        await api.delete(`/issue_reports/${id}`);
        fetchReports();
      } catch (error) {
        console.error("Error deleting report:", error);
        alert("เกิดข้อผิดพลาดในการลบข้อมูล");
      }
    }
  };

  const reportsToDisplay = reports.length > 0 ? reports : mockReports;
  const uniqueTypes = Array.from(new Set(reportsToDisplay.map(r => r.issue_type).filter(Boolean)));

  // Pagination calculation
  const filteredAndSorted = reportsToDisplay
    .filter(item => {
      const matchSearch = 
        (item.issue_type || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
        (item.description || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
        (item.user_id || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
        (item.status || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
        String(item.report_id || '').toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchType = typeFilter === 'all' || item.issue_type === typeFilter;
      const matchStatus = statusFilter === 'all' || item.status === statusFilter;

      return matchSearch && matchType && matchStatus;
    })
    .sort((a, b) => {
      const compare = String(b.report_id || '').localeCompare(String(a.report_id || ''));
      return sortOrder === 'newest' ? compare : -compare;
    });

  const totalItems = filteredAndSorted.length;
  const totalPages = Math.ceil(totalItems / itemsPerPage) || 1;
  const indexOfLastItem = currentPage * itemsPerPage;
  const indexOfFirstItem = indexOfLastItem - itemsPerPage;
  const currentReports = filteredAndSorted.slice(indexOfFirstItem, indexOfLastItem);

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
                onChange={(e) => setSearchTerm(e.target.value)}
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
          <p>กำลังโหลดข้อมูล...</p>
        ) : (
          <>
            <div className="table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>รหัสรายงาน</th>
                    <th>ผู้ใช้งาน (User ID)</th>
                    <th>ประเภทปัญหา</th>
                    <th>รายละเอียด</th>
                    <th>สถานะ</th>
                    <th>จัดการ</th>
                  </tr>
                </thead>
                <tbody>
                  {currentReports.length > 0 ? (
                    currentReports.map((report) => (
                      <tr key={report.report_id}>
                        <td>{report.report_id}</td>
                        <td>{report.user_id}</td>
                        <td>{report.issue_type}</td>
                        <td style={{ maxWidth: '300px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }} title={report.description}>
                          {report.description}
                        </td>
                        <td>
                          <span style={{ 
                            padding: '4px 8px', 
                            borderRadius: '12px', 
                            fontSize: '0.85rem',
                            backgroundColor: report.status === 'resolved' ? '#d1fae5' : '#fee2e2',
                            color: report.status === 'resolved' ? '#065f46' : '#991b1b'
                          }}>
                            {report.status === 'resolved' ? 'แก้ไขแล้ว' : 'รอดำเนินการ'}
                          </span>
                        </td>
                        <td>
                          <div className="action-links">
                            <button 
                              className="action-btn" 
                              style={{ color: report.status === 'resolved' ? '#9ca3af' : '#10b981' }}
                              onClick={() => handleResolve(report.report_id, report.status)}
                              title="เปลี่ยนสถานะ"
                            >
                              <CheckCircle size={16} />
                            </button>
                            <button className="action-btn delete" onClick={() => handleDelete(report.report_id)}>
                              <Trash2 size={16} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan="6" style={{ textAlign: 'center' }}>ไม่พบข้อมูลรายงานปัญหา</td>
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
    </div>
  );
};

export default IssueReports;
