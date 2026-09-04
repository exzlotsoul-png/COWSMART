import React, { useState, useEffect } from 'react';
import {
  Bot, Plus, Edit, Trash2, Search, Filter, CheckCircle2,
  AlertCircle, Sparkles, MessageSquare, BookOpen, Check, X,
  ArrowUpDown, RefreshCw, Send, Eye, ShieldCheck, AlertTriangle,
  Database, Smartphone, Stethoscope
} from 'lucide-react';
import api from '../lib/axios';
import { useToast } from '../contexts/ToastContext';

const AiChatbotManagement = () => {
  const { showToast } = useToast();
  const [knowledges, setKnowledges] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [selectedStatus, setSelectedStatus] = useState('all');

  // Form Modal State (Add / Edit)
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingItem, setEditingItem] = useState(null);
  const [formData, setFormData] = useState({
    category: 'อาการทางเดินอาหาร',
    title: '',
    keywords: '',
    prompt: '',
    answer: '',
    suggested_actions: ['create_appointment', 'record_health'],
    is_active: true,
    sort_order: 0
  });

  // Delete Confirm Modal State
  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [itemToDelete, setItemToDelete] = useState(null);
  const [isDeleting, setIsDeleting] = useState(false);

  // Test Chat State
  const [isTestOpen, setIsTestOpen] = useState(false);
  const [testMessage, setTestMessage] = useState('');
  const [testLoading, setTestLoading] = useState(false);
  const [testResponse, setTestResponse] = useState(null);

  const defaultCategories = [
    'อาการทางเดินอาหาร',
    'โรคติดเชื้อและไข้',
    'แม่วัวและการคลอด',
    'วัคซีนและการบำรุง',
  ];

  useEffect(() => {
    fetchKnowledges();
  }, [selectedCategory]);

  const showNotification = (text, type = 'success') => {
    showToast(text, type);
  };

  const fetchKnowledges = async () => {
    setLoading(true);
    try {
      const params = {};
      if (selectedCategory !== 'all') {
        params.category = selectedCategory;
      }
      const response = await api.get('/ai_chatbot', { params });
      if (response.data && response.data.data) {
        setKnowledges(response.data.data);
        if (response.data.categories) {
          setCategories(response.data.categories);
        }
      }
    } catch (error) {
      console.error('Error fetching AI chatbot knowledges:', error);
      showNotification('ไม่สามารถโหลดข้อมูลคำถาม-คำตอบ AI ได้', 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleOpenModal = (item = null) => {
    if (item) {
      setEditingItem(item);
      setFormData({
        category: item.category || 'อาการทางเดินอาหาร',
        title: item.title || '',
        keywords: item.keywords || '',
        prompt: item.prompt || '',
        answer: item.answer || '',
        suggested_actions: item.suggested_actions || ['create_appointment', 'record_health'],
        is_active: item.is_active !== undefined ? Boolean(item.is_active) : true,
        sort_order: item.sort_order || 0
      });
    } else {
      setEditingItem(null);
      setFormData({
        category: categories.length > 0 ? categories[0] : 'อาการทางเดินอาหาร',
        title: '',
        keywords: '',
        prompt: '',
        answer: '',
        suggested_actions: ['create_appointment', 'record_health'],
        is_active: true,
        sort_order: knowledges.length + 1
      });
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setEditingItem(null);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!formData.title || !formData.prompt || !formData.answer) {
      showNotification('กรุณากรอกหัวข้อ, คำถามด่วน และคำตอบทางการแพทย์ให้ครบถ้วน', 'error');
      return;
    }

    try {
      if (editingItem) {
        await api.put(`/ai_chatbot/${editingItem.id}`, formData);
        showNotification('อัปเดตชุดคำถาม-คำตอบ AI สำเร็จ');
      } else {
        await api.post('/ai_chatbot', formData);
        showNotification('เพิ่มชุดคำถาม-คำตอบ AI เรียบร้อยแล้ว');
      }
      handleCloseModal();
      fetchKnowledges();
    } catch (error) {
      console.error('Error saving AI chatbot knowledge:', error);
      showNotification('เกิดข้อผิดพลาดในการบันทึกข้อมูล', 'error');
    }
  };

  // Open Delete Modal
  const handleOpenDeleteModal = (item) => {
    setItemToDelete(item);
    setDeleteModalOpen(true);
  };

  const handleCloseDeleteModal = () => {
    setItemToDelete(null);
    setDeleteModalOpen(false);
    setIsDeleting(false);
  };

  // Confirm Delete
  const handleConfirmDelete = async () => {
    if (!itemToDelete) return;
    setIsDeleting(true);
    try {
      await api.delete(`/ai_chatbot/${itemToDelete.id}`);
      showNotification('ลบชุดความรู้เรียบร้อยแล้ว');
      handleCloseDeleteModal();
      fetchKnowledges();
    } catch (error) {
      console.error('Error deleting AI knowledge:', error);
      showNotification('ไม่สามารถลบข้อมูลได้', 'error');
      setIsDeleting(false);
    }
  };

  const handleToggleActive = async (item) => {
    try {
      await api.put(`/ai_chatbot/${item.id}`, {
        is_active: !item.is_active
      });
      fetchKnowledges();
      showNotification(`ปรับสถานะ "${item.title}" เป็น ${!item.is_active ? 'เปิดใช้งาน' : 'ปิดใช้งาน'} เรียบร้อย`);
    } catch (error) {
      console.error('Error toggling status:', error);
      showNotification('ไม่สามารถเปลี่ยนสถานะได้', 'error');
    }
  };

  const handleTestConsult = async (e) => {
    e.preventDefault();
    if (!testMessage.trim()) return;

    setTestLoading(true);
    setTestResponse(null);
    try {
      const response = await api.post('/ai/consult', {
        message: testMessage
      });
      setTestResponse(response.data);
    } catch (error) {
      console.error('Error testing consultation:', error);
      setTestResponse({
        ai_response: 'เกิดข้อผิดพลาดในการเชื่อมต่อ API'
      });
    } finally {
      setTestLoading(false);
    }
  };

  const toggleActionCheckbox = (actionKey) => {
    const current = [...(formData.suggested_actions || [])];
    if (current.includes(actionKey)) {
      setFormData({ ...formData, suggested_actions: current.filter(a => a !== actionKey) });
    } else {
      setFormData({ ...formData, suggested_actions: [...current, actionKey] });
    }
  };

  // Filtered List
  const filteredKnowledges = knowledges.filter(item => {
    const matchesSearch =
      (item.title && item.title.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (item.keywords && item.keywords.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (item.prompt && item.prompt.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (item.answer && item.answer.toLowerCase().includes(searchTerm.toLowerCase()));

    const matchesCategory = selectedCategory === 'all' || item.category === selectedCategory;
    const matchesStatus =
      selectedStatus === 'all' ||
      (selectedStatus === 'active' && item.is_active) ||
      (selectedStatus === 'inactive' && !item.is_active);

    return matchesSearch && matchesCategory && matchesStatus;
  });

  return (
    <div>
      {/* 4 Summary Stat Cards matching Dashboard */}
      <div className="summary-cards-grid">
        <div className="summary-card">
          <div className="summary-info">
            <p>ชุดความรู้ทั้งหมดใน DB</p>
            <h3>{knowledges.length}</h3>
          </div>
          <div className="summary-icon green-icon">
            <Database size={24} />
          </div>
        </div>

        <div className="summary-card">
          <div className="summary-info">
            <p>เปิดใช้งานบนแอป (Active)</p>
            <h3>{knowledges.filter(k => k.is_active).length}</h3>
          </div>
          <div className="summary-icon blue-icon">
            <Smartphone size={24} />
          </div>
        </div>

        <div className="summary-card">
          <div className="summary-info">
            <p>หมวดหมู่อาการและโรค</p>
            <h3>{new Set(knowledges.map(k => k.category)).size}</h3>
          </div>
          <div className="summary-icon purple-icon">
            <Stethoscope size={24} />
          </div>
        </div>

        <div className="summary-card">
          <div className="summary-info">
            <p>ระบบค้นหา & AI Fallback</p>
            <h3 style={{ fontSize: '1.4rem' }}>DB + Gemini</h3>
          </div>
          <div className="summary-icon orange-icon">
            <Bot size={24} />
          </div>
        </div>
      </div>

      {/* Main Table Card */}
      <div className="card">
        <div className="card-header">
          <div>
            <h2 className="card-title" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Bot size={24} style={{ color: 'var(--primary-color)' }} />
              จัดการคำถามด่วน AI ผู้ช่วยหมอ
            </h2>
            <p style={{ margin: '4px 0 0 0', fontSize: '0.85rem', color: 'var(--text-muted)' }}>
              กำหนดคำถามด่วน คำค้นหา และแนวทางการรักษาจากสัตวแพทย์เพื่อให้ AI ตอบคำถามได้อย่างถูกต้อง
            </p>
          </div>

          <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
            <button
              className="btn btn-outline"
              onClick={() => setIsTestOpen(!isTestOpen)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                backgroundColor: isTestOpen ? '#e0f2fe' : '#f8fafc',
                borderColor: '#7dd3fc',
                color: '#0369a1'
              }}
            >
              <MessageSquare size={16} />
              {isTestOpen ? 'ซ่อนหน้าต่างทดสอบแชท' : 'ทดสอบถามตอบ AI'}
            </button>

            <button className="btn btn-primary" onClick={() => handleOpenModal()}>
              <Plus size={16} />
              เพิ่มคำถาม-คำตอบใหม่
            </button>
          </div>
        </div>

        {/* Live Test Consultation Drawer */}
        {isTestOpen && (
          <div style={{
            margin: '0 24px 20px 24px',
            padding: '18px',
            backgroundColor: '#f0fdf4',
            border: '1px solid #86efac',
            borderRadius: '12px'
          }}>
            <h4 style={{ margin: '0 0 10px 0', fontSize: '0.95rem', color: '#166534', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Sparkles size={16} /> ทดสอบการประมวลผลของ AIchatbotController
            </h4>
            <form onSubmit={handleTestConsult} style={{ display: 'flex', gap: '10px', marginBottom: '12px' }}>
              <input
                type="text"
                className="form-control"
                placeholder="พิมพ์คำถามทดสอบ เช่น วัวท้องอืด, ปากเปื่อย, ตารางวัคซีน..."
                value={testMessage}
                onChange={(e) => setTestMessage(e.target.value)}
                style={{ flex: 1, backgroundColor: '#fff' }}
              />
              <button
                type="submit"
                className="btn btn-primary"
                disabled={testLoading}
                style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
              >
                <Send size={15} />
                {testLoading ? 'กำลังประมวลผล...' : 'ทดสอบส่งคำถาม'}
              </button>
            </form>

            {testResponse && (
              <div style={{
                padding: '14px',
                backgroundColor: '#ffffff',
                border: '1px solid #bbf7d0',
                borderRadius: '8px',
                fontSize: '0.85rem',
                color: 'var(--text-main)',
                whiteSpace: 'pre-wrap',
                lineHeight: '1.6'
              }}>
                <div style={{ fontWeight: '700', color: '#166534', marginBottom: '6px' }}>ผลลัพธ์จาก AI หมอวัว:</div>
                {testResponse.ai_response}
              </div>
            )}
          </div>
        )}

        {/* Filters and Search Bar */}
        <div style={{
          padding: '16px 24px',
          display: 'flex',
          gap: '12px',
          flexWrap: 'wrap',
          alignItems: 'center',
          borderBottom: '1px solid var(--border-color)',
          backgroundColor: '#fafafa'
        }}>
          {/* Search Box */}
          <div style={{ position: 'relative', flex: 1, minWidth: '240px' }}>
            <Search size={16} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
            <input
              type="text"
              className="form-control"
              placeholder="ค้นหาตามหัวข้อ, คีย์เวิร์ด, หรือคำตอบ..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              style={{ paddingLeft: '36px' }}
            />
          </div>

          {/* Category Filter */}
          <div style={{ minWidth: '180px' }}>
            <select
              className="form-control"
              value={selectedCategory}
              onChange={(e) => setSelectedCategory(e.target.value)}
            >
              <option value="all">ทุกหมวดหมู่</option>
              {defaultCategories.map((cat, idx) => (
                <option key={idx} value={cat}>{cat}</option>
              ))}
            </select>
          </div>

          {/* Status Filter */}
          <div style={{ minWidth: '140px' }}>
            <select
              className="form-control"
              value={selectedStatus}
              onChange={(e) => setSelectedStatus(e.target.value)}
            >
              <option value="all">สถานะทั้งหมด</option>
              <option value="active">เปิดใช้งาน</option>
              <option value="inactive">ปิดใช้งาน</option>
            </select>
          </div>

          <button
            className="btn btn-outline"
            onClick={fetchKnowledges}
            style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
            title="รีเฟรชข้อมูล"
          >
            <RefreshCw size={15} />
          </button>
        </div>

        {/* Table Content */}
        <div style={{ overflowX: 'auto' }}>
          <table className="data-table">
            <thead>
              <tr>
                <th style={{ width: '60px', textAlign: 'center' }}>ลำดับ</th>
                <th style={{ width: '180px' }}>หมวดหมู่</th>
                <th style={{ width: '220px' }}>หัวข้อ / อาการ</th>
                <th>คำค้นหา / คีย์เวิร์ด (Keywords)</th>
                <th>คำถามด่วน (Prompt)</th>
                <th style={{ width: '90px', textAlign: 'center' }}>สถานะ</th>
                <th style={{ width: '110px', textAlign: 'center' }}>จัดการ</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>
                    <RefreshCw size={24} style={{ animation: 'spin 1s linear infinite', margin: '0 auto 8px auto' }} />
                    <div>กำลังโหลดชุดความรู้ AI จากฐานข้อมูล...</div>
                  </td>
                </tr>
              ) : filteredKnowledges.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>
                    ไม่พบข้อมูลคำถาม-คำตอบตามเงื่อนไขที่ค้นหา
                  </td>
                </tr>
              ) : (
                filteredKnowledges.map((item, idx) => (
                  <tr key={item.id}>
                    <td style={{ textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.85rem' }}>
                      {item.sort_order || idx + 1}
                    </td>
                    <td>
                      <span style={{
                        display: 'inline-block',
                        padding: '4px 10px',
                        borderRadius: '6px',
                        backgroundColor: '#f1f5f9',
                        color: '#334155',
                        fontSize: '0.8rem',
                        fontWeight: '600'
                      }}>
                        {item.category}
                      </span>
                    </td>
                    <td>
                      <div style={{ fontWeight: '700', color: 'var(--text-main)', fontSize: '0.9rem' }}>
                        {item.title}
                      </div>
                      {item.suggested_actions && item.suggested_actions.length > 0 && (
                        <div style={{ display: 'flex', gap: '4px', marginTop: '4px' }}>
                          {item.suggested_actions.includes('create_appointment') && (
                            <span style={{ fontSize: '0.7rem', backgroundColor: '#e0f2fe', color: '#0369a1', padding: '1px 6px', borderRadius: '4px' }}>
                              นัดตรวจ
                            </span>
                          )}
                          {item.suggested_actions.includes('record_health') && (
                            <span style={{ fontSize: '0.7rem', backgroundColor: '#fef3c7', color: '#92400e', padding: '1px 6px', borderRadius: '4px' }}>
                              บันทึกรักษา
                            </span>
                          )}
                        </div>
                      )}
                    </td>
                    <td>
                      <div style={{ fontSize: '0.8rem', color: '#475569', display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
                        {item.keywords ? item.keywords.split(',').map((kw, i) => (
                          <span key={i} style={{ backgroundColor: '#f8fafc', border: '1px solid #e2e8f0', padding: '1px 6px', borderRadius: '4px' }}>
                            {kw.trim()}
                          </span>
                        )) : '-'}
                      </div>
                    </td>
                    <td style={{ fontSize: '0.82rem', color: 'var(--text-main)', maxWidth: '280px' }}>
                      <div style={{
                        display: '-webkit-box',
                        WebkitLineClamp: 2,
                        WebkitBoxOrient: 'vertical',
                        overflow: 'hidden'
                      }}>
                        {item.prompt}
                      </div>
                    </td>
                    <td style={{ textAlign: 'center' }}>
                      <button
                        onClick={() => handleToggleActive(item)}
                        style={{
                          border: 'none',
                          background: 'none',
                          cursor: 'pointer',
                          padding: '4px',
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '4px',
                          fontSize: '0.75rem',
                          fontWeight: '600',
                          color: item.is_active ? '#16a34a' : '#94a3b8'
                        }}
                      >
                        {item.is_active ? (
                          <span style={{ backgroundColor: 'var(--primary-light)', color: 'var(--primary-color)', padding: '3px 10px', borderRadius: '12px', fontWeight: '700' }}>
                            เปิดใช้
                          </span>
                        ) : (
                          <span style={{ backgroundColor: '#f1f5f9', color: '#64748b', padding: '3px 10px', borderRadius: '12px', fontWeight: '600' }}>
                            ปิด
                          </span>
                        )}
                      </button>
                    </td>
                    <td style={{ textAlign: 'center' }}>
                      <div style={{ display: 'flex', justifyContent: 'center', gap: '6px' }}>
                        <button
                          className="btn btn-outline"
                          style={{ padding: '5px 8px', fontSize: '0.75rem' }}
                          onClick={() => handleOpenModal(item)}
                          title="แก้ไข"
                        >
                          <Edit size={14} />
                        </button>
                        <button
                          className="btn btn-outline"
                          style={{ padding: '5px 8px', fontSize: '0.75rem', borderColor: '#fca5a5', color: '#dc2626' }}
                          onClick={() => handleOpenDeleteModal(item)}
                          title="ลบ"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal Add / Edit Knowledge Item */}
      {isModalOpen && (
        <div className="modal-overlay" onClick={handleCloseModal}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '680px', maxHeight: '90vh', overflowY: 'auto' }}>
            <div className="modal-header">
              <h3 className="modal-title" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Bot size={20} color="var(--primary-color)" />
                {editingItem ? 'แก้ไขชุดคำถาม-คำตอบ AI' : 'เพิ่มชุดคำถาม-คำตอบ AI ใหม่'}
              </h3>
              <button className="modal-close" onClick={handleCloseModal}>&times;</button>
            </div>

            <form onSubmit={handleSave}>
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                  <div className="form-group">
                    <label className="form-label">หมวดหมู่อาการหรือความรู้ *</label>
                    <select
                      className="form-control"
                      value={formData.category}
                      onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                      required
                    >
                      {defaultCategories.map((cat, idx) => (
                        <option key={idx} value={cat}>{cat}</option>
                      ))}
                    </select>
                  </div>

                  <div className="form-group">
                    <label className="form-label">ลำดับการแสดงผล (Sort Order)</label>
                    <input
                      type="number"
                      className="form-control"
                      value={formData.sort_order}
                      onChange={(e) => setFormData({ ...formData, sort_order: parseInt(e.target.value, 10) || 0 })}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label className="form-label">หัวข้อคำถาม หรืออาการ *</label>
                  <input
                    type="text"
                    className="form-control"
                    placeholder="เช่น วัวท้องอืด / ท้องซ้ายบวม"
                    value={formData.title}
                    onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                    required
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">คำค้นหา หรือคีย์เวิร์ดที่เกี่ยวข้อง (คั่นด้วยจุลภาค)</label>
                  <input
                    type="text"
                    className="form-control"
                    placeholder="เช่น ท้องอืด, ท้องบวม, จุกเสียด, ไม่เคี้ยวเอื้อง, bloat"
                    value={formData.keywords}
                    onChange={(e) => setFormData({ ...formData, keywords: e.target.value })}
                  />
                  <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '3px', display: 'block' }}>
                    เมื่อเกษตรกรพิมพ์คำที่มีคีย์เวิร์ดเหล่านี้ ระบบจะดึงคำตอบนี้มาตอบอัตโนมัติ
                  </span>
                </div>

                <div className="form-group">
                  <label className="form-label">ข้อความของคำถาม</label>
                  <input
                    type="text"
                    className="form-control"
                    placeholder="เช่น วัวมีอาการท้องอืด ท้องด้านซ้ายบวม ไม่ยอมเคี้ยวเอื้อง ต้องปฐมพยาบาลอย่างไร?"
                    value={formData.prompt}
                    onChange={(e) => setFormData({ ...formData, prompt: e.target.value })}
                    required
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">คำตอบ หรือคำแนะนำการรักษาของสัตวแพทย์ *</label>
                  <textarea
                    className="form-control"
                    rows="7"
                    placeholder="ใส่คำแนะนำการปฐมพยาบาล, การให้ยา, สัญญาณอันตราย และการป้องกัน..."
                    value={formData.answer}
                    onChange={(e) => setFormData({ ...formData, answer: e.target.value })}
                    required
                    style={{ fontFamily: 'inherit', fontSize: '0.88rem', lineHeight: '1.5' }}
                  ></textarea>
                </div>

                {/* Suggested Actions Selector */}
                <div className="form-group">
                  <label className="form-label">ปุ่ม Action แนะนำใต้คำตอบ:</label>
                  <div style={{ display: 'flex', gap: '16px', marginTop: '6px' }}>
                    <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer', fontSize: '0.85rem' }}>
                      <input
                        type="checkbox"
                        checked={formData.suggested_actions?.includes('create_appointment')}
                        onChange={() => toggleActionCheckbox('create_appointment')}
                      />
                      <span>สร้างนัดหมายตรวจสุขภาพ</span>
                    </label>
                    <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer', fontSize: '0.85rem' }}>
                      <input
                        type="checkbox"
                        checked={formData.suggested_actions?.includes('record_health')}
                        onChange={() => toggleActionCheckbox('record_health')}
                      />
                      <span>บันทึกประวัติการรักษา</span>
                    </label>
                  </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '4px' }}>
                  <input
                    type="checkbox"
                    id="is_active_toggle"
                    checked={formData.is_active}
                    onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                  />
                  <label htmlFor="is_active_toggle" style={{ fontSize: '0.88rem', fontWeight: '600', cursor: 'pointer' }}>
                    เปิดใช้งานบนแอปมือถือทันที
                  </label>
                </div>
              </div>

              <div className="modal-footer" style={{ marginTop: '16px' }}>
                <button type="button" className="btn btn-outline" onClick={handleCloseModal}>
                  ยกเลิก
                </button>
                <button type="submit" className="btn btn-primary">
                  บันทึกข้อมูล
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {deleteModalOpen && itemToDelete && (
        <div className="modal-overlay" onClick={handleCloseDeleteModal}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '440px' }}>
            <div className="modal-header">
              <h3 className="modal-title" style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#dc2626' }}>
                <AlertTriangle size={20} color="#dc2626" />
                ยืนยันการลบชุดความรู้
              </h3>
              <button className="modal-close" onClick={handleCloseDeleteModal}>&times;</button>
            </div>
            <div className="modal-body" style={{ fontSize: '0.9rem', color: 'var(--text-main)', lineHeight: '1.6' }}>
              คุณแน่ใจหรือไม่ที่จะลบชุดความรู้ <strong>"{itemToDelete.title}"</strong> ออกจากระบบฐานข้อมูล?
              <div style={{ marginTop: '8px', fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                การลบนี้จะทำให้ AI ไม่สามารถดึงคำตอบนี้มาตอบบนแอปได้อีกต่อไป
              </div>
            </div>
            <div className="modal-footer" style={{ marginTop: '18px' }}>
              <button type="button" className="btn btn-outline" onClick={handleCloseDeleteModal} disabled={isDeleting}>
                ยกเลิก
              </button>
              <button
                type="button"
                className="btn btn-primary"
                onClick={handleConfirmDelete}
                disabled={isDeleting}
                style={{ backgroundColor: '#dc2626', borderColor: '#dc2626' }}
              >
                {isDeleting ? 'กำลังลบ...' : 'ยืนยันการลบ'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AiChatbotManagement;
