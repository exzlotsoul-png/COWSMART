import React, { useState, useEffect } from 'react';
import { CheckCircle, Trash2 } from 'lucide-react';
import api from '../lib/axios';

const IssueReports = () => {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchReports();
  }, []);

  const fetchReports = async () => {
    try {
      const response = await api.get('/issue_reports');
      setReports(response.data.data || response.data);
    } catch (error) {
      console.error("Error fetching reports:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleResolve = async (id, currentStatus) => {
    const newStatus = currentStatus === 'resolved' ? 'pending' : 'resolved';
    try {
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
        await api.delete(`/issue_reports/${id}`);
        fetchReports();
      } catch (error) {
        console.error("Error deleting report:", error);
        alert("เกิดข้อผิดพลาดในการลบข้อมูล");
      }
    }
  };

  return (
    <div>
      <div className="card">
        <div className="card-header">
          <h2 className="card-title">จัดการรายงานการใช้งาน</h2>
        </div>

        {loading ? (
          <p>กำลังโหลดข้อมูล...</p>
        ) : (
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
                {reports.length > 0 ? (
                  reports.map((report) => (
                    <tr key={report.report_id}>
                      <td>{report.report_id}</td>
                      <td>{report.user_id}</td>
                      <td>{report.issue_type}</td>
                      <td style={{ maxWidth: '300px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
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
        )}
      </div>
    </div>
  );
};

export default IssueReports;
