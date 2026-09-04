import React, { useState, useEffect, useCallback } from 'react';
import { Users, Tractor, PawPrint, Baby, AlertCircle, Lightbulb, MessageSquare, RefreshCw } from 'lucide-react';
import {
  PieChart, Pie, Cell, ResponsiveContainer, Tooltip as RechartsTooltip
} from 'recharts';
import api from '../lib/axios';
import './Dashboard.css';

const Dashboard = () => {
  const months = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
  ];

  const now = new Date();
  const currentMonthName = months[now.getMonth()];
  const currentYearBE = String(now.getFullYear() + 543);

  // Dynamic years list around current Buddhist Era year
  const baseYear = now.getFullYear() + 543;
  const years = [
    String(baseYear - 2),
    String(baseYear - 1),
    String(baseYear),
    String(baseYear + 1)
  ];

  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [diseaseLoading, setDiseaseLoading] = useState(false);
  const [diseaseMonth, setDiseaseMonth] = useState(currentMonthName);
  const [diseaseYear, setDiseaseYear] = useState(currentYearBE);
  const [healthMonth, setHealthMonth] = useState(currentMonthName);
  const [healthYear, setHealthYear] = useState(currentYearBE);

  const fetchDashboardData = useCallback(async (isInitial = false) => {
    if (isInitial) {
      setLoading(true);
    } else {
      setDiseaseLoading(true);
    }
    try {
      const response = await api.get('/dashboard', {
        params: {
          disease_month: diseaseMonth,
          disease_year: diseaseYear,
          health_month: healthMonth,
          health_year: healthYear
        }
      });
      setData(response.data.data);
    } catch (error) {
      console.error("Error fetching dashboard data:", error);
    } finally {
      setLoading(false);
      setDiseaseLoading(false);
    }
  }, [diseaseMonth, diseaseYear, healthMonth, healthYear]);

  useEffect(() => {
    fetchDashboardData(true);
  }, []);

  useEffect(() => {
    // Re-fetch when filter changes
    fetchDashboardData(false);
  }, [diseaseMonth, diseaseYear, healthMonth, healthYear, fetchDashboardData]);

  if (loading) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
        <RefreshCw size={28} style={{ animation: 'spin 1s linear infinite', margin: '0 auto 12px auto' }} />
        <div>กำลังโหลดข้อมูลสรุป...</div>
      </div>
    );
  }

  if (!data) {
    return <div style={{ padding: '24px', textAlign: 'center' }}>ไม่สามารถดึงข้อมูลได้</div>;
  }

  const { summary, latest_reports, top_diseases, popular_breeds, health_status } = data;

  // Mock fallback only if latest reports from API is empty
  const mockReports = [
    {
      id: 101,
      topic: "ปัญหาการบันทึกข้อมูลน้ำนม",
      description: "กดบันทึกน้ำนมดิบแล้วระบบหมุนค้างและขึ้น Error 500 ครับ",
      first_name: "สมชาย",
      last_name: "ใจดี",
      email: "somchai@gmail.com",
      created_at: new Date(Date.now() - 3600000 * 2).toISOString()
    },
    {
      id: 102,
      topic: "ข้อเสนอแนะ: อยากให้ออกรายงาน PDF ได้",
      description: "อยากให้เพิ่มปุ่มส่งออกข้อมูลประวัติการรักษาของวัวเป็นไฟล์ PDF เพื่อพิมพ์ใช้งานในฟาร์ม",
      first_name: "สมหญิง",
      last_name: "รักดี",
      email: "somying@farm.com",
      created_at: new Date(Date.now() - 3600000 * 5).toISOString()
    }
  ];

  const reportsToDisplay = latest_reports && latest_reports.length > 0 ? latest_reports : mockReports;
  const diseasesToDisplay = top_diseases || [];

  // --- Process Breed Data ---
  const breedColors = ['#5b8c6b', '#c97d60', '#8c6239', '#2d5a43'];
  let totalBreedCount = 0;
  const breedData = (popular_breeds || []).map((item, index) => {
    totalBreedCount += item.count;
    return {
      name: item.breed_name || 'ไม่ระบุ',
      value: item.count,
      color: breedColors[index % breedColors.length]
    };
  });

  // --- Process Health Data ---
  let healthy = 0;
  let sick = 0;
  let pregnant = 0;

  if (health_status && Array.isArray(health_status)) {
    health_status.forEach(item => {
      const s = (item.status || '').toLowerCase();
      const count = parseInt(item.count, 10) || 0;

      if (s === 'sick' || s === 'injured' || s.includes('ป่วย') || s.includes('บาดเจ็บ')) {
        sick += count;
      } else if (s === 'pregnant' || s.includes('ท้อง')) {
        pregnant += count;
      } else if (s !== 'sold' && s !== 'deceased' && s !== 'removed' && s !== 'ขายแล้ว' && s !== 'ตาย' && s !== 'คัดทิ้ง') {
        healthy += count;
      }
    });
  }

  const totalHealthCount = healthy + sick + pregnant;

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
    return { icon: <MessageSquare size={12} />, label: 'ทั่วไป', color: '#2563eb', bg: '#dbeafe' };
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

  const maxDiseaseCount = diseasesToDisplay.length > 0 ? (diseasesToDisplay[0].count || 1) : 1;

  return (
    <div className="dashboard-container">
      <div style={{ marginBottom: '24px' }}>
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
            <svg width="28" height="28" viewBox="0 0 512 512" fill="none">
              <g fill="currentColor">
                <path d="M 140 180 C 110 130 160 100 190 140 C 170 150 150 165 140 180 Z" />
                <path d="M 372 180 C 402 130 352 100 322 140 C 342 150 362 165 372 180 Z" />
                <path d="M 150 205 C 90 205 90 250 155 240 Z" />
                <path d="M 362 205 C 422 205 422 250 357 240 Z" />
                <path d="M 170 170 L 342 170 C 360 210 360 270 330 320 L 182 320 C 152 270 152 210 170 170 Z" />
                <rect x="180" y="290" width="152" height="110" rx="45" fill="#f1f8e9" />
                <circle cx="215" cy="345" r="14" fill="#2d5a43" />
                <circle cx="297" cy="345" r="14" fill="#2d5a43" />
                <ellipse cx="215" cy="225" rx="14" ry="18" fill="#ffffff" />
                <ellipse cx="297" cy="225" rx="14" ry="18" fill="#ffffff" />
              </g>
            </svg>
          </div>
        </div>

        <div className="summary-card">
          <div className="summary-info">
            <p>จำนวนลูกเกิดใหม่</p>
            <h3>{summary.newborns}</h3>
          </div>
          <div className="summary-icon lightblue-icon">
            <svg width="28" height="28" viewBox="0 0 512 512" fill="none">
              <g fill="currentColor">
                <path d="M 155 185 C 135 145 170 120 190 150 Z" />
                <path d="M 357 185 C 377 145 342 120 322 150 Z" />
                <path d="M 155 215 C 95 220 95 260 155 250 Z" />
                <path d="M 357 215 C 417 220 417 260 357 250 Z" />
                <circle cx="256" cy="256" r="115" />
                <rect x="186" y="295" width="140" height="90" rx="40" fill="#fff9eb" />
                <circle cx="222" cy="340" r="11" fill="#b8923e" />
                <circle cx="290" cy="340" r="11" fill="#b8923e" />
                <circle cx="212" cy="225" r="16" fill="#ffffff" />
                <circle cx="300" cy="225" r="16" fill="#ffffff" />
                <circle cx="215" cy="223" r="8" fill="#b8923e" />
                <circle cx="303" cy="223" r="8" fill="#b8923e" />
              </g>
              <path d="M 405 105 L 413 130 L 438 138 L 413 146 L 405 171 L 397 146 L 372 138 L 397 130 Z" fill="#f59e0b" />
            </svg>
          </div>
        </div>
      </div>

      {/* --- Main Content 2 Columns --- */}
      <div className="dashboard-main-grid">

        {/* Left Column */}
        <div className="dashboard-left">

          {/* Recent Reports */}
          <div className="db-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
              <h3 className="db-card-title" style={{ margin: 0 }}>รายงานปัญหาและการใช้งานล่าสุด</h3>
              <a href="/issue-reports" style={{ fontSize: '0.875rem', color: 'var(--primary-color)', textDecoration: 'none', fontWeight: '600' }}>ดูทั้งหมด</a>
            </div>

            <div className="db-table-container">
              <table className="db-table">
                <thead>
                  <tr>
                    <th>วันที่</th>
                    <th>ผู้รายงาน</th>
                    <th>ประเภท</th>
                    <th>รายละเอียด</th>
                  </tr>
                </thead>
                <tbody>
                  {reportsToDisplay.length > 0 ? (
                    reportsToDisplay.map((report) => {
                      const tag = getIssueTag(report.topic);
                      return (
                        <tr key={report.id}>
                          <td style={{ color: '#000000', fontSize: '0.8rem', whiteSpace: 'nowrap', fontWeight: '500' }}>
                            {new Date(report.created_at).toLocaleDateString('th-TH', {
                              day: 'numeric',
                              month: 'short',
                              year: '2-digit'
                            })}
                          </td>
                          <td>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                              <div className="user-avatar-small">
                                {(report.first_name?.[0] || report.email?.[0] || 'U').toUpperCase()}
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
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', flexWrap: 'wrap', gap: '12px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <h3 className="db-card-title" style={{ margin: 0 }}>สถิติแยกตามประเภทโรค (Top 5)</h3>
                {diseaseLoading && <RefreshCw size={14} style={{ animation: 'spin 1s linear infinite', color: 'var(--primary-color)' }} />}
              </div>
              <div style={{ display: 'flex', gap: '8px' }}>
                <select className="db-select" value={diseaseMonth} onChange={(e) => setDiseaseMonth(e.target.value)}>
                  {months.map((m) => (
                    <option key={m} value={m}>{m}</option>
                  ))}
                </select>
                <select className="db-select" value={diseaseYear} onChange={(e) => setDiseaseYear(e.target.value)}>
                  {years.map((y) => (
                    <option key={y} value={y}>{y}</option>
                  ))}
                </select>
              </div>
            </div>

            <div className="db-table-container">
              <table className="db-table no-border">
                <thead>
                  <tr>
                    <th>ชื่อโรค / อาการ</th>
                    <th>จำนวนเคส ({diseaseMonth})</th>
                    <th>แนวโน้ม</th>
                    <th style={{ textAlign: 'right' }}>สถานะ</th>
                  </tr>
                </thead>
                <tbody>
                  {diseasesToDisplay && diseasesToDisplay.length > 0 ? (
                    diseasesToDisplay.map((disease, idx) => {
                      const percent = Math.min(100, Math.max(15, Math.round((disease.count / maxDiseaseCount) * 100)));

                      let statusText = 'ควบคุมได้';
                      let statusColor = 'var(--primary-color)';
                      let barColor = 'var(--primary-color)';

                      if (disease.count >= 7) {
                        statusText = 'กำลังระบาด';
                        statusColor = '#ef4444';
                        barColor = '#ef4444';
                      } else if (disease.count >= 4) {
                        statusText = 'เฝ้าระวัง';
                        statusColor = '#d97706';
                        barColor = '#f59e0b';
                      }

                      return (
                        <tr key={idx}>
                          <td style={{ fontWeight: '500' }}>{disease.disease_name}</td>
                          <td style={{ fontWeight: '600' }}>{disease.count}</td>
                          <td>
                            <div className="progress-bar-bg" style={{ height: '8px', borderRadius: '4px', backgroundColor: '#f1f5f9', overflow: 'hidden' }}>
                              <div
                                className="progress-bar-fill"
                                style={{
                                  width: `${percent}%`,
                                  backgroundColor: barColor,
                                  height: '100%',
                                  borderRadius: '4px',
                                  transition: 'width 0.5s ease-in-out'
                                }}
                              ></div>
                            </div>
                          </td>
                          <td style={{ textAlign: 'right', fontSize: '0.875rem', fontWeight: '700', color: statusColor }}>
                            {statusText}
                          </td>
                        </tr>
                      );
                    })
                  ) : (
                    <tr>
                      <td colSpan="4" style={{ textAlign: 'center', padding: '30px 20px', color: 'var(--text-muted)' }}>
                        ไม่มีข้อมูลสถิติโรคในเดือน {diseaseMonth} {diseaseYear}
                      </td>
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
              <div className="donut-center">
                <span className="donut-value">{totalBreedCount}</span>
                <span className="donut-label">ตัวทั้งหมด</span>
              </div>
            </div>

            <div className="chart-legend-bottom">
              {breedData.map((item, idx) => (
                <div key={idx} className="legend-item-bottom">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <div className="legend-dot" style={{ backgroundColor: item.color, flexShrink: 0 }}></div>
                    <span style={{ fontSize: '0.875rem', color: '#374151' }}>{item.name}</span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <span style={{ fontWeight: '700', fontSize: '0.95rem', color: '#111827' }}>{item.value}</span>
                    <span style={{ fontSize: '0.8rem', color: '#6b7280' }}>ตัว</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Health Proportion Chart */}
          <div className="db-card">
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginBottom: '8px' }}>
              <select className="db-select" style={{ fontSize: '0.75rem', padding: '4px 8px' }} value={healthMonth} onChange={(e) => setHealthMonth(e.target.value)}>
                {months.map((m) => (
                  <option key={m} value={m}>{m}</option>
                ))}
              </select>
              <select className="db-select" style={{ fontSize: '0.75rem', padding: '4px 8px' }} value={healthYear} onChange={(e) => setHealthYear(e.target.value)}>
                {years.map((y) => (
                  <option key={y} value={y}>{y}</option>
                ))}
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

                      return percent > 0 ? (
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
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <div className="legend-dot" style={{ backgroundColor: item.color, flexShrink: 0 }}></div>
                    <span style={{ fontSize: '0.875rem', color: '#374151' }}>{item.name}</span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                    <span style={{ fontWeight: '700', fontSize: '0.95rem', color: '#111827' }}>{item.value}</span>
                    <span style={{ fontSize: '0.8rem', color: '#6b7280' }}>ตัว</span>
                  </div>
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
