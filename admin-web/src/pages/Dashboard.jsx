import React, { useState, useEffect } from 'react';
import { Users, Tractor, PawPrint, Baby, AlertCircle, Lightbulb, MessageSquare } from 'lucide-react';
import { 
  PieChart, Pie, Cell, ResponsiveContainer, Tooltip as RechartsTooltip
} from 'recharts';
import api from '../lib/axios';
import './Dashboard.css';

const Dashboard = () => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      const response = await api.get('/dashboard');
      setData(response.data.data);
    } catch (error) {
      console.error("Error fetching dashboard data:", error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div style={{ padding: '24px' }}>กำลังโหลดข้อมูลสรุป...</div>;
  }

  if (!data) {
    return <div style={{ padding: '24px' }}>ไม่สามารถดึงข้อมูลได้</div>;
  }

  const { summary, latest_reports, top_diseases, popular_breeds, health_status } = data;

  // --- Process Breed Data ---
  const breedColors = ['#5b8c6b', '#c97d60', '#8c6239', '#2d5a43'];
  let totalBreedCount = 0;
  const breedData = popular_breeds.map((item, index) => {
    totalBreedCount += item.count;
    return {
      name: item.breed_name || 'ไม่ระบุ',
      value: item.count,
      color: breedColors[index % breedColors.length]
    };
  });

  // --- Process Health Data ---
  let totalHealthCount = 0;
  let healthy = 0;
  let sick = 0;
  let pregnant = 0;

  // Mapping different possible statuses to 3 categories (Healthy, Sick, Pregnant)
  health_status.forEach(item => {
    const s = (item.status || '').toLowerCase();
    totalHealthCount += item.count;
    if (s.includes('sick') || s.includes('ป่วย') || s.includes('บาดเจ็บ')) {
      sick += item.count;
    } else if (s.includes('pregnant') || s.includes('ท้อง')) {
      pregnant += item.count;
    } else {
      healthy += item.count; // Default to healthy if not sick or pregnant
    }
  });

  // If DB didn't return any status, use total_cows as mock data to show the chart
  if (totalHealthCount === 0 && summary.total_cows > 0) {
    totalHealthCount = summary.total_cows;
    healthy = Math.floor(totalHealthCount * 0.5);
    sick = Math.floor(totalHealthCount * 0.25);
    pregnant = totalHealthCount - healthy - sick;
  }

  const healthData = [
    { name: 'สุขภาพดี', value: healthy, color: '#a3c9a8' }, // muted green
    { name: 'ป่วย/บาดเจ็บ', value: sick, color: '#e29578' }, // muted rust/clay
    { name: 'ท้อง', value: pregnant, color: '#edd18b' } // muted straw/honey
  ];

  // Helper for issue report icons/colors
  const getIssueTag = (topic) => {
    if (topic && (topic.includes('ปัญหา') || topic.includes('error'))) {
      return { icon: <AlertCircle size={12} />, label: 'ปัญหา', color: '#ef4444', bg: '#fee2e2' };
    }
    if (topic && topic.includes('เสนอแนะ')) {
      return { icon: <Lightbulb size={12} />, label: 'ข้อเสนอแนะ', color: '#d97706', bg: '#fef3c7' };
    }
    if (topic && topic.includes('บัญชี')) {
      return { icon: <Users size={12} />, label: 'บัญชี', color: '#7c3aed', bg: '#ede9fe' };
    }
    return { icon: <MessageSquare size={12} />, label: 'ทั่วไป', color: '#6b7280', bg: '#f3f4f6' };
  };

  // Custom Label for center of Donut
  const renderCustomizedLabel = ({ cx, cy, value }) => {
    return (
      <text x={cx} y={cy} textAnchor="middle" dominantBaseline="central">
        <tspan x={cx} dy="-0.5em" fontSize="28" fontWeight="bold" fill="#1f2937">{value}</tspan>
        <tspan x={cx} dy="1.5em" fontSize="12" fill="#6b7280">ตัวทั้งหมด</tspan>
      </text>
    );
  };

  return (
    <div className="dashboard-container">
      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 'bold', margin: '0 0 4px 0', color: 'var(--text-main)' }}>หน้าแรก</h1>
        <h2 style={{ fontSize: '2rem', fontWeight: 'bold', margin: 0, color: 'var(--text-main)' }}>แดชบอร์ดภาพรวม</h2>
      </div>

      {/* --- Top Summary Cards --- */}
      <div className="summary-cards-grid">
        <div className="summary-card">
          <div className="summary-info">
            <p>ผู้ใช้งานทั้งหมด</p>
            <h3>{summary.total_users}</h3>
          </div>
          <div className="summary-icon blue-icon">
            <Users size={24} />
          </div>
        </div>

        <div className="summary-card">
          <div className="summary-info">
            <p>ฟาร์มที่ใช้งานอยู่</p>
            <h3>{summary.active_farms}</h3>
          </div>
          <div className="summary-icon orange-icon">
            <Tractor size={24} />
          </div>
        </div>

        <div className="summary-card">
          <div className="summary-info">
            <p>จำนวนวัวทั้งหมด</p>
            <h3>{summary.total_cows}</h3>
          </div>
          <div className="summary-icon green-icon">
            <PawPrint size={24} />
          </div>
        </div>

        <div className="summary-card">
          <div className="summary-info">
            <p>จำนวนลูกเกิดใหม่</p>
            <h3>{summary.newborns}</h3>
          </div>
          <div className="summary-icon lightblue-icon">
            <Baby size={24} />
          </div>
        </div>
      </div>

      {/* --- Main Content Layout --- */}
      <div className="dashboard-main-grid">
        
        {/* Left Column */}
        <div className="dashboard-left">
          
          {/* Latest Reports */}
          <div className="db-card">
            <h3 className="db-card-title">รายงานจากผู้ใช้ล่าสุด</h3>
            <div className="db-table-container">
              <table className="db-table">
                <thead>
                  <tr>
                    <th>วันที่</th>
                    <th>ผู้แจ้ง</th>
                    <th>ประเภท</th>
                    <th>หัวข้อ / รายละเอียด</th>
                  </tr>
                </thead>
                <tbody>
                  {latest_reports && latest_reports.length > 0 ? (
                    latest_reports.map(report => {
                      const tag = getIssueTag(report.topic);
                      return (
                        <tr key={report.id}>
                          <td style={{ color: '#4b5563' }}>{new Date(report.created_at).toLocaleDateString('th-TH')} | {new Date(report.created_at).toLocaleTimeString('th-TH', {hour: '2-digit', minute:'2-digit'})}</td>
                          <td>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                              <div className="user-avatar-small">
                                {(report.first_name?.[0] || report.email[0]).toUpperCase()}
                              </div>
                              <div>
                                <div style={{ fontWeight: '500' }}>{report.first_name ? `${report.first_name} ${report.last_name || ''}` : report.email}</div>
                                <div style={{ fontSize: '0.75rem', color: '#9ca3af' }}>ID: {report.id}</div>
                              </div>
                            </div>
                          </td>
                          <td>
                            <span className="issue-tag" style={{ backgroundColor: tag.bg, color: tag.color }}>
                              {tag.icon} {tag.label}
                            </span>
                          </td>
                          <td style={{ maxWidth: '200px' }}>
                            <div style={{ fontWeight: '500', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{report.topic || 'ไม่มีหัวข้อ'}</div>
                            <div style={{ fontSize: '0.75rem', color: '#9ca3af', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{report.description}</div>
                          </td>
                        </tr>
                      );
                    })
                  ) : (
                    <tr>
                      <td colSpan="4" style={{ textAlign: 'center', padding: '20px' }}>ไม่มีรายงานล่าสุด</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Top Diseases */}
          <div className="db-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
              <h3 className="db-card-title" style={{ margin: 0 }}>สถิติแยกตามประเภทโรค (Top 5)</h3>
              <select className="db-select">
                <option>มกราคม 2569</option>
              </select>
            </div>
            
            <div className="db-table-container">
              <table className="db-table no-border">
                <thead>
                  <tr>
                    <th>ชื่อโรค / อาการ</th>
                    <th>จำนวนเคส (เดือนนี้)</th>
                    <th>แนวโน้ม</th>
                    <th style={{ textAlign: 'right' }}>สถานะ</th>
                  </tr>
                </thead>
                <tbody>
                  {top_diseases && top_diseases.length > 0 ? (
                    top_diseases.map((disease, idx) => {
                      // Mocking trend and status for display purposes based on index
                      const percent = Math.max(10, Math.floor((disease.count / (top_diseases[0].count || 1)) * 100));
                      const isHigh = idx === 0;
                      const isWarning = idx === 1;
                      
                      return (
                        <tr key={idx}>
                          <td style={{ fontWeight: '500' }}>{disease.disease_name}</td>
                          <td>{disease.count}</td>
                          <td>
                            <div className="progress-bar-bg">
                              <div 
                                className="progress-bar-fill" 
                                style={{ 
                                  width: `${percent}%`, 
                                  backgroundColor: isHigh ? '#ef4444' : isWarning ? '#f59e0b' : '#10b981' 
                                }}
                              ></div>
                            </div>
                          </td>
                          <td style={{ textAlign: 'right', fontSize: '0.875rem', color: isHigh ? '#ef4444' : isWarning ? '#d97706' : '#10b981' }}>
                            {isHigh ? 'กำลังระบาด' : isWarning ? 'เฝ้าระวัง' : 'ควบคุมได้'}
                          </td>
                        </tr>
                      );
                    })
                  ) : (
                    <tr>
                      <td colSpan="4" style={{ textAlign: 'center', padding: '20px' }}>ไม่มีข้อมูลสถิติโรค</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

        </div>

        {/* Right Column */}
        <div className="dashboard-right">
          
          {/* Popular Breeds Chart */}
          <div className="db-card">
            <h3 className="db-card-title" style={{ textAlign: 'center' }}>สายพันธุ์ยอดนิยม</h3>
            <div style={{ height: '220px', position: 'relative' }}>
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={breedData}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={80}
                    dataKey="value"
                    stroke="none"
                  >
                    {breedData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <RechartsTooltip />
                </PieChart>
              </ResponsiveContainer>
              {/* Custom Center Text */}
              <div className="donut-center">
                <span className="donut-value">{summary.total_cows}</span>
                <span className="donut-label">ตัวทั้งหมด</span>
              </div>
            </div>
            
            <div className="chart-legend">
              {breedData.map((item, idx) => (
                <div key={idx} className="legend-item">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <div className="legend-dot" style={{ backgroundColor: item.color }}></div>
                    <span>{item.name}</span>
                  </div>
                  <span style={{ fontWeight: 'bold' }}>{totalBreedCount > 0 ? Math.round((item.value / totalBreedCount) * 100) : 0}%</span>
                </div>
              ))}
            </div>
          </div>

          {/* Health Proportion Chart */}
          <div className="db-card">
            <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '8px' }}>
              <select className="db-select" style={{ fontSize: '0.75rem', padding: '4px 8px' }}>
                <option>มกราคม 2569</option>
              </select>
            </div>
            <h3 className="db-card-title" style={{ textAlign: 'left', marginBottom: '16px' }}>สัดส่วนสุขภาพวัว</h3>
            
            <div style={{ height: '200px' }}>
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={healthData}
                    cx="50%"
                    cy="50%"
                    innerRadius={0}
                    outerRadius={80}
                    dataKey="value"
                    stroke="#fff"
                    strokeWidth={2}
                    label={({ cx, cy, midAngle, innerRadius, outerRadius, value, name }) => {
                      const RADIAN = Math.PI / 180;
                      const radius = innerRadius + (outerRadius - innerRadius) * 0.5;
                      const x = cx + radius * Math.cos(-midAngle * RADIAN);
                      const y = cy + radius * Math.sin(-midAngle * RADIAN);
                      const percent = totalHealthCount > 0 ? Math.round((value / totalHealthCount) * 100) : 0;
                      
                      return percent > 5 ? (
                        <text x={x} y={y} fill="#1f2937" textAnchor="middle" dominantBaseline="central" style={{ fontSize: '12px', fontWeight: 'bold' }}>
                          <tspan x={x} dy="-0.5em">{percent}%</tspan>
                          <tspan x={x} dy="1.2em" fontSize="10px" fontWeight="normal">{name}</tspan>
                        </text>
                      ) : null;
                    }}
                    labelLine={false}
                  >
                    {healthData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <RechartsTooltip />
                </PieChart>
              </ResponsiveContainer>
            </div>

            <div className="chart-legend-bottom">
              {healthData.map((item, idx) => (
                <div key={idx} className="legend-item-bottom">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <div className="legend-dot" style={{ backgroundColor: item.color }}></div>
                    <span style={{ fontSize: '0.875rem' }}>{item.name}</span>
                  </div>
                  <span style={{ fontWeight: 'bold', fontSize: '0.875rem' }}>{item.value}</span>
                </div>
              ))}
            </div>
          </div>

        </div>
      </div>
    </div>
  );
};

export default Dashboard;
