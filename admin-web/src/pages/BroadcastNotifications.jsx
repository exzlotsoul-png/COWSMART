import React, { useState, useEffect } from 'react';
import { 
  Megaphone, Send, Users, Bell, AlertTriangle, Sparkles, 
  Trash2, Eye, RefreshCw, CheckCircle2, 
  Smartphone, Search, Filter, Info, X, Clock,
  Calendar, Layers, Check, Wrench, Sprout, BriefcaseMedical,
  ChevronLeft, CheckCheck
} from 'lucide-react';
import api from '../lib/axios';
import './BroadcastNotifications.css';

const BroadcastNotifications = () => {
  const [broadcasts, setBroadcasts] = useState([]);
  const [stats, setStats] = useState({ total_users: 0, total_broadcasts: 0, total_notifications: 0 });
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [notification, setNotification] = useState(null);

  // Form State
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [category, setCategory] = useState('ประกาศทั่วไป');
  const [targetType, setTargetType] = useState('all');

  // Filter & Search
  const [searchTerm, setSearchTerm] = useState('');

  // Modals
  const [confirmModalOpen, setConfirmModalOpen] = useState(false);
  const [detailModalOpen, setDetailModalOpen] = useState(false);
  const [selectedBroadcast, setSelectedBroadcast] = useState(null);
  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [itemToDelete, setItemToDelete] = useState(null);
  const [deleting, setDeleting] = useState(false);

  // Template Presets (Using Lucide icon components, NO raw emoji characters)
  const templates = [
    {
      icon: Wrench,
      label: 'ปิดปรับปรุงระบบ',
      category: 'ปรับปรุงระบบ',
      title: 'แจ้งปิดปรับปรุงระบบเซิร์ฟเวอร์ชั่วคราว',
      message: 'ระบบ CowSmart จะทำการปิดปรับปรุงประสิทธิภาพเซิร์ฟเวอร์ในคืนนี้ เวลา 00:00 - 02:00 น. ขออภัยในความไม่สะดวกครับ'
    },
    {
      icon: AlertTriangle,
      label: 'เตือนภัยโรคระบาด',
      category: 'แจ้งเตือนโรคและสุขภาพ',
      title: 'แจ้งเตือนเฝ้าระวังโรคลัมปี สกิน และ ปากเท้าเปื่อย',
      message: 'ขอความร่วมมือเกษตรกรทุกท่านหมั่นตรวจเช็กร่างกายวัว พ่นยากำจัดแมลงดูดเลือด และกักแยกสัตว์ป่วยทันทีหากพบอาการผิดปกติ'
    },
    {
      icon: Sparkles,
      label: 'อัปเดตฟีเจอร์ใหม่',
      category: 'อัปเดตระบบ',
      title: 'อัปเดตใหม่: ระบบปรึกษาหมอวัว AI ผู้ช่วยฟาร์ม',
      message: 'ท่านสามารถเข้าใช้งานฟีเจอร์ AI ช่วยวินิจฉัยโรคและแนะนำการดูแลวัวเบื้องต้นได้แล้ววันนี้ในแท็บ AI Chatbot'
    },
    {
      icon: Sprout,
      label: 'แนะนำโภชนาการ',
      category: 'ข่าวสารและคำแนะนำ',
      title: 'แนะนำการสำรองหญ้าและอาหารสัตว์รับมือหน้าแล้ง',
      message: 'กรมปศุสัตว์แนะนำให้เกษตรกรเตรียมทำหญ้าหมักและสำรองฟางแห้ง เพื่อรักษาความสมบูรณ์และน้ำหนักตัวของโคเนื้อ'
    }
  ];

  // Category list (Clean text without emoji, mapped to icon components)
  const categories = [
    { id: 'ประกาศทั่วไป', label: 'ประกาศทั่วไป', icon: Megaphone, color: '#2d5a43', bg: '#e8f0eb' },
    { id: 'แจ้งเตือนโรคและสุขภาพ', label: 'สุขภาพ / โรคระบาด', icon: AlertTriangle, color: '#d97706', bg: '#fef3c7' },
    { id: 'ปรับปรุงระบบ', label: 'ปรับปรุงระบบ', icon: Wrench, color: '#2563eb', bg: '#dbeafe' },
    { id: 'อัปเดตระบบ', label: 'อัปเดตฟีเจอร์', icon: Sparkles, color: '#7c3aed', bg: '#ede9fe' },
    { id: 'ข่าวสารและคำแนะนำ', label: 'ข่าวสารและคำแนะนำ', icon: Info, color: '#0891b2', bg: '#cffafe' },
  ];

  useEffect(() => {
    fetchBroadcasts();
  }, []);

  const showToast = (text, type = 'success') => {
    setNotification({ text, type });
    setTimeout(() => setNotification(null), 4000);
  };

  const fetchBroadcasts = async () => {
    setLoading(true);
    try {
      const res = await api.get('/admin/broadcast-notifications');
      if (res.data && res.data.success) {
        setBroadcasts(res.data.data || []);
        if (res.data.stats) {
          setStats(res.data.stats);
        }
      }
    } catch (err) {
      console.error('Error fetching broadcasts:', err);
      showToast('ไม่สามารถดึงข้อมูลประวัติประกาศได้', 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleApplyTemplate = (tmpl) => {
    setTitle(tmpl.title);
    setMessage(tmpl.message);
    setCategory(tmpl.category);
    showToast(`นำเข้าเทมเพลต "${tmpl.label}" เรียบร้อย`, 'info');
  };

  const handleSendBroadcast = async () => {
    if (!title.trim() || !message.trim()) {
      showToast('กรุณากรอกหัวข้อและข้อความประกาศให้ครบถ้วน', 'error');
      return;
    }

    setSending(true);
    try {
      const res = await api.post('/admin/broadcast-notifications', {
        title: title.trim(),
        message: message.trim(),
        category,
        target_type: targetType,
      });

      if (res.data && res.data.success) {
        showToast(res.data.message || 'ส่งประกาศแจ้งเตือนถึงผู้ใช้ทุกคนเรียบร้อยแล้ว!', 'success');
        setConfirmModalOpen(false);
        setTitle('');
        setMessage('');
        fetchBroadcasts();
      }
    } catch (err) {
      console.error('Error sending broadcast:', err);
      showToast(err.response?.data?.message || 'เกิดข้อผิดพลาดในการส่งประกาศ', 'error');
    } finally {
      setSending(false);
    }
  };

  const handleDeleteBroadcast = async () => {
    if (!itemToDelete) return;
    setDeleting(true);
    try {
      const res = await api.post('/admin/broadcast-notifications/delete-group', {
        broadcast_key: itemToDelete.broadcast_key,
        id: itemToDelete.id,
        title: itemToDelete.title,
      });

      if (res.data && res.data.success) {
        showToast('ลบประกาศแจ้งเตือนสำเร็จ', 'success');
        setDeleteModalOpen(false);
        setItemToDelete(null);
        fetchBroadcasts();
      }
    } catch (err) {
      console.error('Error deleting broadcast:', err);
      showToast('ไม่สามารถลบประกาศได้', 'error');
    } finally {
      setDeleting(false);
    }
  };

  const filteredBroadcasts = broadcasts.filter((item) => {
    const matchSearch = item.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
                        item.message.toLowerCase().includes(searchTerm.toLowerCase());
    return matchSearch;
  });

  return (
    <div className="broadcast-page">
      {/* Toast Notification */}
      {notification && (
        <div style={{
          position: 'fixed',
          top: '24px',
          right: '24px',
          zIndex: 1000,
          background: notification.type === 'error' ? '#ef4444' : notification.type === 'info' ? '#3b82f6' : '#2d5a43',
          color: '#fff',
          padding: '14px 20px',
          borderRadius: '14px',
          boxShadow: '0 10px 25px -5px rgba(0,0,0,0.2)',
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          fontWeight: '600',
          fontSize: '0.9rem',
          animation: 'slideDown 0.3s ease'
        }}>
          {notification.type === 'error' ? <AlertTriangle size={18} /> : <CheckCircle2 size={18} />}
          <span>{notification.text}</span>
        </div>
      )}

      {/* 3 Summary Stat Cards */}
      <div className="broadcast-summary-grid">
        <div className="summary-card">
          <div className="summary-info">
            <p>ผู้ใช้งานในระบบ (เป้าหมาย)</p>
            <h3>{stats.total_users}</h3>
          </div>
          <div className="summary-icon green-icon">
            <Users size={24} />
          </div>
        </div>

        <div className="summary-card">
          <div className="summary-info">
            <p>ประกาศที่ส่งแล้ว</p>
            <h3>{stats.total_broadcasts}</h3>
          </div>
          <div className="summary-icon orange-icon">
            <Megaphone size={24} />
          </div>
        </div>

        <div className="summary-card">
          <div className="summary-info">
            <p>การแจ้งเตือนทั้งหมดในระบบ</p>
            <h3>{stats.total_notifications}</h3>
          </div>
          <div className="summary-icon blue-icon">
            <Bell size={24} />
          </div>
        </div>
      </div>

      {/* Main Grid: Form vs Live Mobile Simulator */}
      <div className="broadcast-content-grid">
        {/* Left: Broadcast Form */}
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <div className="card-header">
            <div>
              <h2 className="card-title" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Megaphone size={22} style={{ color: 'var(--primary-color)' }} />
                ระบบส่งประกาศ & แจ้งเตือนแอดมิน
              </h2>
              <p style={{ margin: '4px 0 0 0', color: 'var(--text-muted)', fontSize: '0.85rem' }}>
                สร้างและกระจายข้อความแจ้งเตือนถึงผู้ใช้งานแอปพลิเคชัน CowSmart ทุกคนพร้อมกันแบบ Real-time
              </p>
            </div>
          </div>

          <div className="card-body">

          {/* Quick Template Buttons with Icons (No Raw Emojis) */}
          <div style={{ marginBottom: '16px' }}>
            <span style={{ fontSize: '0.84rem', fontWeight: '600', color: 'var(--text-muted)', display: 'block', marginBottom: '8px' }}>
              เลือกเทมเพลตข้อความด่วน:
            </span>
            <div className="template-pills">
              {templates.map((tmpl, idx) => {
                const IconComponent = tmpl.icon;
                return (
                  <button
                    key={idx}
                    type="button"
                    className="template-pill-btn"
                    onClick={() => handleApplyTemplate(tmpl)}
                  >
                    <IconComponent size={15} color="var(--primary-color)" />
                    <span>{tmpl.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Category Selection Dropdown */}
          <div className="bc-form-group">
            <label className="bc-form-label" htmlFor="broadcast-category">
              หมวดหมู่ของประกาศ
            </label>
            <select
              id="broadcast-category"
              className="bc-select"
              value={category}
              onChange={(e) => setCategory(e.target.value)}
            >
              {categories.map((cat) => (
                <option key={cat.id} value={cat.id}>
                  {cat.label}
                </option>
              ))}
            </select>
          </div>

          {/* Title Input */}
          <div className="bc-form-group">
            <label className="bc-form-label" htmlFor="broadcast-title">
              หัวข้อประกาศ <span style={{ color: '#ef4444' }}>*</span>
            </label>
            <input
              id="broadcast-title"
              type="text"
              className="bc-input"
              placeholder="เช่น ประกาศปิดปรับปรุงระบบคืนนี้ หรือ แจ้งเตือนเฝ้าระวังโรคระบาด"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={200}
            />
            <div className="char-counter">{title.length} / 200 ตัวอักษร</div>
          </div>

          {/* Message Textarea */}
          <div className="bc-form-group">
            <label className="bc-form-label" htmlFor="broadcast-message">
              เนื้อหา / รายละเอียดประกาศ <span style={{ color: '#ef4444' }}>*</span>
            </label>
            <textarea
              id="broadcast-message"
              className="bc-textarea"
              placeholder="พิมพ์เนื้อหาการแจ้งเตือนที่ต้องการให้แสดงในแอปพลิเคชันของผู้ใช้งาน..."
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              maxLength={1000}
            />
            <div className="char-counter">{message.length} / 1000 ตัวอักษร</div>
          </div>

          {/* Target Audience */}
          <div className="bc-form-group">
            <label className="bc-form-label">กลุ่มเป้าหมายผู้รับ</label>
            <div className="target-audience-box">
              <div
                className={`audience-option ${targetType === 'all' ? 'active' : ''}`}
                onClick={() => setTargetType('all')}
              >
                <div className="audience-radio">
                  {targetType === 'all' && <div className="audience-radio-inner" />}
                </div>
                <div className="audience-text">
                  <span className="title">ผู้ใช้งานทุกคนในระบบ</span>
                  <span className="subtitle">ส่งถึงทุกบัญชี ({stats.total_users} บัญชี)</span>
                </div>
              </div>

              <div
                className={`audience-option ${targetType === 'active' ? 'active' : ''}`}
                onClick={() => setTargetType('active')}
              >
                <div className="audience-radio">
                  {targetType === 'active' && <div className="audience-radio-inner" />}
                </div>
                <div className="audience-text">
                  <span className="title">เฉพาะบัญชีที่เปิดใช้งาน</span>
                  <span className="subtitle">เฉพาะผู้ใช้งานสถานะ Active</span>
                </div>
              </div>
            </div>
          </div>

          {/* Submit Button */}
          <button
            type="button"
            className="btn-send-broadcast"
            disabled={!title.trim() || !message.trim() || sending}
            onClick={() => setConfirmModalOpen(true)}
          >
            <Send size={18} />
            <span>ส่งประกาศแจ้งเตือนถึงผู้ใช้ทุกคน</span>
          </button>
          </div>
        </div>

        {/* Right: Live Smartphone Notification Simulator (Exact Pixel Match with CowSmart Flutter App) */}
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <div className="card-header">
            <h3 className="card-title" style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '1.05rem' }}>
              <Smartphone size={20} style={{ color: 'var(--primary-color)' }} />
              Live Preview บนแอปมือถือ
            </h3>
          </div>

          <div className="card-body simulator-container" style={{ padding: '20px' }}>
            <div className="phone-mockup">
              <div className="phone-screen">
                {/* App Screen Top Header (Dark Olive Green) */}
                <div className="app-screen-header">
                  <div className="app-screen-top-bar">
                    <ChevronLeft size={22} color="#ffffff" style={{ cursor: 'pointer' }} />
                    <span className="app-screen-title">การแจ้งเตือน</span>
                    <div className="app-screen-action">
                      <CheckCheck size={16} />
                      <span>อ่านทั้งหมด</span>
                    </div>
                  </div>

                  {/* Summary Header Bar */}
                  <div className="app-screen-summary-bar">
                    <div className="app-summary-icon-box">
                      <Bell size={20} color="#ffffff" />
                    </div>
                    <div className="app-summary-text">
                      <span className="total">ทั้งหมด 1 รายการ</span>
                      <span className="unread">ยังไม่อ่าน 1 รายการ</span>
                    </div>
                    <div className="app-summary-badge">
                      1
                    </div>
                  </div>
                </div>

                {/* Scrollable Notification List */}
                <div className="phone-scroll-body">
                  {/* Active Simulated Notification Card */}
                  <div className="app-notif-card is-active-preview">
                    <div className="app-notif-icon-box" style={{ background: '#fef3c7', color: '#d97706' }}>
                      <Megaphone size={20} />
                    </div>

                    <div className="app-notif-content">
                      <div className="app-notif-top-row">
                        <div className="app-notif-title">
                          {title.trim() || 'หัวข้อประกาศจะปรากฏที่นี่...'}
                        </div>
                        <span className="app-notif-new-badge">ใหม่</span>
                      </div>

                      <div className="app-notif-message">
                        {message.trim() || 'เนื้อหาประกาศจะแสดงผลตัวอย่างแบบเรียลไทม์ที่นี่...'}
                      </div>

                      <div className="app-notif-footer-time">
                        <Clock size={12} />
                        <span>เมื่อสักครู่</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Broadcast History Table */}
      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        <div className="card-header">
          <div>
            <h3 className="card-title" style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '1.05rem' }}>
              <Clock size={20} style={{ color: 'var(--primary-color)' }} />
              ประวัติการส่งประกาศ ({filteredBroadcasts.length} รายการ)
            </h3>
            <p style={{ margin: '4px 0 0 0', color: 'var(--text-muted)', fontSize: '0.85rem' }}>
              รายการข้อความประกาศที่ส่งถึงผู้ใช้งานทั้งหมดในระบบ
            </p>
          </div>

          <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
            <div style={{ position: 'relative' }}>
              <Search size={16} color="var(--text-muted)" style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)' }} />
              <input
                type="text"
                className="bc-input history-search-input"
                style={{ paddingLeft: '36px', height: '40px', fontSize: '0.85rem' }}
                placeholder="ค้นหาตามหัวข้อหรือเนื้อหา..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
            <button
              type="button"
              className="btn-action-icon"
              title="รีเฟรชประวัติ"
              onClick={fetchBroadcasts}
            >
              <RefreshCw size={18} className={loading ? 'animate-spin' : ''} />
            </button>
          </div>
        </div>

        <div className="db-table-container">
          <table className="db-table no-border">
            <thead>
              <tr>
                <th style={{ width: '170px' }}>วันที่และเวลาส่ง</th>
                <th>หัวข้อประกาศ</th>
                <th>เนื้อหาข้อความ</th>
                <th style={{ textAlign: 'center', width: '130px' }}>จำนวนผู้รับ</th>
                <th style={{ textAlign: 'center', width: '130px' }}>เปิดอ่านแล้ว</th>
                <th style={{ textAlign: 'right', width: '110px' }}>จัดการ</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan="6" style={{ textAlign: 'center', padding: '30px' }}>
                    <RefreshCw size={22} style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px', color: 'var(--primary-color)' }} />
                    <div style={{ color: 'var(--text-muted)', fontSize: '0.88rem' }}>กำลังโหลดประวัติประกาศ...</div>
                  </td>
                </tr>
              ) : filteredBroadcasts.length > 0 ? (
                filteredBroadcasts.map((item) => (
                  <tr key={item.broadcast_key || item.id}>
                    <td style={{ fontSize: '0.85rem', color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                      {item.sent_at ? new Date(item.sent_at).toLocaleString('th-TH', { dateStyle: 'medium', timeStyle: 'short' }) : '-'}
                    </td>
                    <td style={{ fontWeight: '700', color: 'var(--text-main)' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <Megaphone size={16} color="var(--primary-color)" />
                        <span>{item.title}</span>
                      </div>
                    </td>
                    <td style={{ maxWidth: '320px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>
                      <div style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {item.message}
                      </div>
                    </td>
                    <td style={{ textAlign: 'center' }}>
                      <span className="badge-tag-pill" style={{ background: '#e8f0eb', color: '#2d5a43' }}>
                        <Users size={13} />
                        {item.recipients_count} บัญชี
                      </span>
                    </td>
                    <td style={{ textAlign: 'center' }}>
                      <span className="badge-tag-pill" style={{ background: '#dbeafe', color: '#2563eb' }}>
                        <Check size={13} />
                        {item.read_count} บัญชี
                      </span>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <div style={{ display: 'inline-flex', gap: '4px' }}>
                        <button
                          type="button"
                          className="btn-action-icon"
                          title="ดูตัวอย่างประกาศ"
                          onClick={() => {
                            setSelectedBroadcast(item);
                            setDetailModalOpen(true);
                          }}
                        >
                          <Eye size={16} />
                        </button>
                        <button
                          type="button"
                          className="btn-action-icon danger"
                          title="ลบประกาศนี้"
                          onClick={() => {
                            setItemToDelete(item);
                            setDeleteModalOpen(true);
                          }}
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan="6" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>
                    <Megaphone size={32} color="#cbd5e1" style={{ margin: '0 auto 8px', display: 'block' }} />
                    <div>ยังไม่มีประวัติการส่งประกาศแจ้งเตือน</div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Confirmation Send Modal */}
      {confirmModalOpen && (
        <div className="bc-modal-overlay">
          <div className="bc-modal-card">
            <div className="modal-header">
              <h3 style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Megaphone size={22} color="var(--primary-color)" />
                ยืนยันการส่งประกาศแจ้งเตือน
              </h3>
              <button type="button" className="modal-close-btn" onClick={() => setConfirmModalOpen(false)}>
                <X size={20} />
              </button>
            </div>

            <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '16px' }}>
              การแจ้งเตือนนี้จะถูกส่งไปยังหน้าการแจ้งเตือนในแอปพลิเคชันของผู้ใช้งานทั้งหมด <strong>{stats.total_users} บัญชี</strong> ทันที:
            </p>

            <div style={{ background: '#f8fafc', padding: '16px', borderRadius: '12px', border: '1px solid #e2e8f0', marginBottom: '20px' }}>
              <div style={{ fontWeight: '700', fontSize: '0.95rem', color: '#0f172a', marginBottom: '6px' }}>
                {title}
              </div>
              <div style={{ fontSize: '0.85rem', color: '#475569', lineHeight: '1.5', whiteSpace: 'pre-line' }}>
                {message}
              </div>
            </div>

            <div className="modal-actions">
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setConfirmModalOpen(false)}
                disabled={sending}
              >
                ยกเลิก
              </button>
              <button
                type="button"
                className="btn btn-primary"
                onClick={handleSendBroadcast}
                disabled={sending}
                style={{ display: 'flex', alignItems: 'center', gap: '8px' }}
              >
                {sending ? (
                  <>
                    <RefreshCw size={16} style={{ animation: 'spin 1s linear infinite' }} />
                    <span>กำลังส่งประกาศ...</span>
                  </>
                ) : (
                  <>
                    <Send size={16} />
                    <span>ยืนยันและส่งทันที</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* View Detail Modal */}
      {detailModalOpen && selectedBroadcast && (
        <div className="bc-modal-overlay">
          <div className="bc-modal-card">
            <div className="modal-header">
              <h3>รายละเอียดประกาศ</h3>
              <button type="button" className="modal-close-btn" onClick={() => setDetailModalOpen(false)}>
                <X size={20} />
              </button>
            </div>

            <div style={{ marginBottom: '16px' }}>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '4px' }}>หัวข้อประกาศ</div>
              <div style={{ fontWeight: '700', fontSize: '1.05rem', color: 'var(--text-main)' }}>
                {selectedBroadcast.title}
              </div>
            </div>

            <div style={{ marginBottom: '16px' }}>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '4px' }}>ข้อความประกาศ</div>
              <div style={{ background: '#f8fafc', padding: '14px', borderRadius: '12px', border: '1px solid #e2e8f0', fontSize: '0.9rem', color: '#334155', lineHeight: '1.5', whiteSpace: 'pre-line' }}>
                {selectedBroadcast.message}
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '20px' }}>
              <div style={{ background: '#e8f0eb', padding: '12px', borderRadius: '10px' }}>
                <span style={{ fontSize: '0.75rem', color: '#2d5a43', fontWeight: '600', display: 'block' }}>จำนวนผู้รับทั้งหมด</span>
                <span style={{ fontSize: '1.1rem', fontWeight: '800', color: '#2d5a43' }}>{selectedBroadcast.recipients_count} บัญชี</span>
              </div>
              <div style={{ background: '#dbeafe', padding: '12px', borderRadius: '10px' }}>
                <span style={{ fontSize: '0.75rem', color: '#2563eb', fontWeight: '600', display: 'block' }}>เปิดอ่านแล้ว</span>
                <span style={{ fontSize: '1.1rem', fontWeight: '800', color: '#2563eb' }}>{selectedBroadcast.read_count} บัญชี</span>
              </div>
            </div>

            <div className="modal-actions">
              <button type="button" className="btn btn-secondary" onClick={() => setDetailModalOpen(false)}>
                ปิดหน้าต่าง
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Confirm Modal */}
      {deleteModalOpen && itemToDelete && (
        <div className="bc-modal-overlay">
          <div className="bc-modal-card">
            <div className="modal-header">
              <h3 style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#dc2626' }}>
                <Trash2 size={22} color="#dc2626" />
                ยืนยันการลบประกาศ
              </h3>
              <button type="button" className="modal-close-btn" onClick={() => setDeleteModalOpen(false)}>
                <X size={20} />
              </button>
            </div>

            <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginBottom: '16px' }}>
              คุณแน่ใจหรือไม่ว่าต้องการลบประกาศ <strong>"{itemToDelete.title}"</strong> ออกจากกล่องข้อความของผู้ใช้งานทั้งหมด?
            </p>

            <div className="modal-actions">
              <button type="button" className="btn btn-secondary" onClick={() => setDeleteModalOpen(false)} disabled={deleting}>
                ยกเลิก
              </button>
              <button
                type="button"
                className="btn btn-danger"
                style={{ background: '#dc2626', color: '#fff' }}
                onClick={handleDeleteBroadcast}
                disabled={deleting}
              >
                {deleting ? 'กำลังลบ...' : 'ยืนยันการลบ'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default BroadcastNotifications;
