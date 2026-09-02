import React, { useState, useEffect, useRef } from 'react';
import { 
  RefreshCw, Plus, Edit, Trash2, Search, ArrowUpDown, TrendingUp, TrendingDown, Tag, 
  Calendar, CheckCircle2, AlertCircle, History, Upload, Image as ImageIcon, 
  Sparkles, Check, X, Filter, Scale, PawPrint, Coins, Award
} from 'lucide-react';
import api from '../lib/axios';
import Pagination from '../components/layout/Pagination';
import { useToast } from '../contexts/ToastContext';

const MarketPrices = () => {
  const { showToast } = useToast();
  const [prices, setPrices] = useState([]);
  const [latestByCategory, setLatestByCategory] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  
  // Year & Month Filters
  const [selectedYear, setSelectedYear] = useState('all'); // 'all', '2569', '2568', '2567'
  const [selectedMonth, setSelectedMonth] = useState('all'); // 'all', '01' to '12'
  const [timeFilter, setTimeFilter] = useState('all'); // all, 30, 60, 90, custom
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [viewMode, setViewMode] = useState('all'); // 'latest' or 'all'
  const [sortOrder, setSortOrder] = useState('newest_date'); // newest_date, oldest_date, price_high, price_low
  
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);
  const [syncMessage, setSyncMessage] = useState(null);
  
  // Single Add/Edit Modal State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentPrice, setCurrentPrice] = useState({
    id: null,
    animal_type: 'cattle',
    category: 'โคพันธุ์ลูกผสม ขนาดกลาง',
    price_per_kg: '',
    effective_date: new Date().toISOString().split('T')[0],
    source: 'NABC AGRI API (agriapi.nabc.go.th) & สศก. (รายสัปดาห์)',
    note: ''
  });
  const [isEditing, setIsEditing] = useState(false);

  // Smart Image Upload / Dropzone Modal State
  const [isImageModalOpen, setIsImageModalOpen] = useState(false);
  const [selectedFile, setSelectedFile] = useState(null);
  const [previewUrl, setPreviewUrl] = useState(null);
  const [parsingImage, setParsingImage] = useState(false);
  const [extractedData, setExtractedData] = useState(null);
  const [savingBatch, setSavingBatch] = useState(false);
  const fileInputRef = useRef(null);

  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  const thaiMonths = [
    { value: '01', name: 'มกราคม' },
    { value: '02', name: 'กุมภาพันธ์' },
    { value: '03', name: 'มีนาคม' },
    { value: '04', name: 'เมษายน' },
    { value: '05', name: 'พฤษภาคม' },
    { value: '06', name: 'มิถุนายน' },
    { value: '07', name: 'กรกฎาคม' },
    { value: '08', name: 'สิงหาคม' },
    { value: '09', name: 'กันยายน' },
    { value: '10', name: 'ตุลาคม' },
    { value: '11', name: 'พฤศจิกายน' },
    { value: '12', name: 'ธันวาคม' },
  ];

  const availableYears = [
    { value: '2569', label: '2569' },
    { value: '2568', label: '2568' },
    { value: '2567', label: '2567' },
  ];

  useEffect(() => {
    fetchPrices();
  }, [selectedYear, selectedMonth, timeFilter, startDate, endDate]);

  const fetchPrices = async () => {
    try {
      setLoading(true);
      const params = {};

      if (selectedYear !== 'all') {
        params.year = selectedYear;
      }
      if (selectedMonth !== 'all') {
        params.month = selectedMonth;
      }

      if (selectedYear === 'all' && selectedMonth === 'all') {
        if (timeFilter === '30' || timeFilter === '60' || timeFilter === '90') {
          params.days = timeFilter;
        } else if (timeFilter === 'custom' && startDate && endDate) {
          params.start_date = startDate;
          params.end_date = endDate;
        }
      }

      const response = await api.get('/market_prices', { params });
      const allData = response.data.data || [];
      const byCat = response.data.by_category || [];

      setPrices(Array.isArray(allData) ? allData : []);
      setLatestByCategory(Array.isArray(byCat) ? byCat : []);
      setCurrentPage(1);
    } catch (error) {
      console.error("Error fetching market prices:", error);
      showToast("ไม่สามารถดึงข้อมูลราคากลางได้", "error");
    } finally {
      setLoading(false);
    }
  };

  const handleSyncLivePrice = async () => {
    try {
      setSyncing(true);
      setSyncMessage(null);

      const params = {};
      if (selectedYear !== 'all') {
        params.year_th = selectedYear;
      }
      if (selectedMonth !== 'all') {
        params.month = selectedMonth;
      }

      const response = await api.post('/market_prices/sync', params);
      showToast(response.data.message || 'ซิงก์ราคากลางสำเร็จ!', 'success');
      setSyncMessage({
        type: 'success',
        text: selectedYear !== 'all' || selectedMonth !== 'all'
          ? `ซิงก์ราคากลาง NABC ประจำปี ${selectedYear !== 'all' ? selectedYear : 'ปัจจุบัน'} เดือน ${selectedMonth !== 'all' ? selectedMonth : 'ทั้งหมด'} สำเร็จแล้ว!`
          : 'ซิงก์ราคากลางรายสัปดาห์จาก NABC AGRI API สำเร็จแล้ว!'
      });
      await fetchPrices();
    } catch (error) {
      console.error("Error syncing market prices:", error);
      showToast('เกิดข้อผิดพลาดในการซิงก์ราคา', 'error');
      setSyncMessage({ type: 'error', text: 'เกิดข้อผิดพลาดในการซิงก์ราคา' });
    } finally {
      setSyncing(false);
      setTimeout(() => setSyncMessage(null), 4000);
    }
  };

  // Image Drag & Drop Handlers
  const handleFileSelect = (file) => {
    if (file && file.type.startsWith('image/')) {
      setSelectedFile(file);
      setPreviewUrl(URL.createObjectURL(file));
      setExtractedData(null);
    } else {
      showToast('กรุณาเลือกไฟล์รูปภาพเท่านั้น', 'warning');
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFileSelect(e.dataTransfer.files[0]);
    }
  };

  const handleScanImage = async () => {
    if (!selectedFile) return;
    try {
      setParsingImage(true);
      const formData = new FormData();
      formData.append('image', selectedFile);

      const response = await api.post('/market_prices/parse-image', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });

      if (response.data.success) {
        setExtractedData(response.data);
        showToast('อ่านข้อมูลจากรูปภาพสำเร็จ', 'success');
      }
    } catch (error) {
      console.error("Error parsing image:", error);
      showToast("เกิดข้อผิดพลาดในการอ่านรูปภาพรายงาน", "error");
    } finally {
      setParsingImage(false);
    }
  };

  const handleExtractedPriceChange = (index, value) => {
    if (!extractedData || !extractedData.items) return;
    const updated = [...extractedData.items];
    updated[index].price_per_kg = parseFloat(value) || 0;
    setExtractedData({ ...extractedData, items: updated });
  };

  const handleBatchDateChange = (newDate) => {
    if (!extractedData || !extractedData.items) return;
    const updated = extractedData.items.map(item => ({
      ...item,
      effective_date: newDate,
    }));
    setExtractedData({ ...extractedData, effective_date: newDate, items: updated });
  };

  const handleSaveBatchPrices = async () => {
    if (!extractedData || !extractedData.items) return;
    try {
      setSavingBatch(true);
      await api.post('/market_prices/batch', { items: extractedData.items });
      setIsImageModalOpen(false);
      setSelectedFile(null);
      setPreviewUrl(null);
      setExtractedData(null);
      showToast(`บันทึกราคากลางจากรูปภาพรายงานสำเร็จ ${extractedData.items.length} รายการ!`, "success");
      setSyncMessage({ type: 'success', text: `บันทึกราคากลางจากรูปภาพรายงานสำเร็จ ${extractedData.items.length} รายการ!` });
      await fetchPrices();
    } catch (error) {
      console.error("Error saving batch prices:", error);
      showToast("เกิดข้อผิดพลาดในการบันทึกข้อมูลราคา", "error");
    } finally {
      setSavingBatch(false);
      setTimeout(() => setSyncMessage(null), 4000);
    }
  };

  const handleOpenModal = (price = null) => {
    if (price) {
      let rawDate = price.effective_date || '';
      if (rawDate.includes('T')) {
        rawDate = rawDate.split('T')[0];
      }
      setCurrentPrice({
        id: price.id,
        animal_type: price.animal_type || 'cattle',
        category: price.category || 'โคพันธุ์ลูกผสม ขนาดกลาง',
        price_per_kg: price.price_per_kg || '',
        effective_date: rawDate || new Date().toISOString().split('T')[0],
        source: price.source || 'NABC AGRI API (agriapi.nabc.go.th) & สศก. (รายสัปดาห์)',
        note: price.note || ''
      });
      setIsEditing(true);
    } else {
      setCurrentPrice({
        id: null,
        animal_type: 'cattle',
        category: 'โคพันธุ์ลูกผสม ขนาดกลาง',
        price_per_kg: '',
        effective_date: new Date().toISOString().split('T')[0],
        source: 'NABC AGRI API (agriapi.nabc.go.th) & สศก. (รายสัปดาห์)',
        note: ''
      });
      setIsEditing(false);
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setIsEditing(false);
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setCurrentPrice(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (isEditing) {
        await api.put(`/market_prices/${currentPrice.id}`, currentPrice);
        showToast("แก้ไขข้อมูลราคากลางเรียบร้อยแล้ว", "success");
      } else {
        await api.post('/market_prices', currentPrice);
        showToast("เพิ่มข้อมูลราคากลางใหม่เรียบร้อยแล้ว", "success");
      }
      handleCloseModal();
      fetchPrices();
    } catch (error) {
      console.error("Error saving market price:", error);
      showToast("เกิดข้อผิดพลาดในการบันทึกข้อมูลราคา", "error");
    }
  };

  const handleDelete = async (id, category = '') => {
    if (window.confirm(`คุณแน่ใจหรือไม่ที่จะลบรายการราคา "${category || id}"?`)) {
      try {
        await api.delete(`/market_prices/${id}`);
        showToast(`ลบรายการราคา "${category || id}" เรียบร้อยแล้ว`, "info");
        fetchPrices();
      } catch (error) {
        console.error("Error deleting market price:", error);
        showToast("เกิดข้อผิดพลาดในการลบรายการราคา", "error");
      }
    }
  };

  const formatThaiDate = (dateStr) => {
    if (!dateStr) return '-';
    try {
      const cleanDate = dateStr.split('T')[0];
      const parts = cleanDate.split('-');
      if (parts.length === 3) {
        const thaiMonthNames = [
          'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
          'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
        ];
        const day = parseInt(parts[2], 10);
        const month = thaiMonthNames[parseInt(parts[1], 10) - 1];
        const year = parseInt(parts[0], 10) + 543;
        return `${day} ${month} ${year}`;
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  };

  const getPriceForCategory = (catName) => {
    let found = latestByCategory.find(p => p.category === catName);
    if (!found) {
      const normCat = catName.replace(/≤/g, '<=').replace(/\s+/g, '');
      found = latestByCategory.find(p => {
        const itemNorm = (p.category || '').replace(/≤/g, '<=').replace(/\s+/g, '');
        return itemNorm === normCat;
      });
    }
    if (!found) {
      found = latestByCategory.find(p => p.category && p.category.includes(catName));
    }
    return found ? `${parseFloat(found.price_per_kg).toFixed(2)} บาท` : '-';
  };

  const getSourceForCategory = (catName) => {
    let found = latestByCategory.find(p => p.category === catName);
    if (!found) {
      const normCat = catName.replace(/≤/g, '<=').replace(/\s+/g, '');
      found = latestByCategory.find(p => {
        const itemNorm = (p.category || '').replace(/≤/g, '<=').replace(/\s+/g, '');
        return itemNorm === normCat;
      });
    }
    if (!found) {
      found = latestByCategory.find(p => p.category && p.category.includes(catName));
    }
    return found?.source || 'NABC AGRI API';
  };

  const getPriceTrendForCategory = (catName) => {
    const normCat = catName.replace(/≤/g, '<=').replace(/\s+/g, '');
    const items = prices.filter(p => {
      if (p.category === catName) return true;
      const itemNorm = (p.category || '').replace(/≤/g, '<=').replace(/\s+/g, '');
      if (itemNorm === normCat) return true;
      return p.category && p.category.includes(catName);
    }).sort((a, b) => (b.effective_date || '').localeCompare(a.effective_date || ''));

    if (items.length >= 2) {
      const latestPrice = parseFloat(items[0].price_per_kg || 0);
      const prevPrice = parseFloat(items[1].price_per_kg || 0);
      if (latestPrice < prevPrice) {
        return 'down'; // price dropped -> orange/peach
      } else {
        return 'up'; // price equal or up -> green
      }
    }
    return 'up';
  };

  // Base list depending on View Mode
  const baseList = viewMode === 'latest' ? latestByCategory : prices;

  // Filter & Sorting Logic
  const filteredPrices = baseList.filter(item => {
    const matchesSearch = 
      (item.category && item.category.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (item.source && item.source.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (item.note && item.note.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (item.effective_date && item.effective_date.includes(searchTerm));
      
    const matchesCategory = categoryFilter === 'all' || item.category === categoryFilter;
    return matchesSearch && matchesCategory;
  }).sort((a, b) => {
    if (sortOrder === 'newest_date') {
      return (b.effective_date || '').localeCompare(a.effective_date || '');
    } else if (sortOrder === 'oldest_date') {
      return (a.effective_date || '').localeCompare(b.effective_date || '');
    } else if (sortOrder === 'price_high') {
      return parseFloat(b.price_per_kg || 0) - parseFloat(a.price_per_kg || 0);
    } else if (sortOrder === 'price_low') {
      return parseFloat(a.price_per_kg || 0) - parseFloat(b.price_per_kg || 0);
    }
    return 0;
  });

  const totalPages = Math.ceil(filteredPrices.length / itemsPerPage) || 1;
  const currentItems = filteredPrices.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  );

  return (
    <div>
      {/* Top Banner Alert Message */}
      {syncMessage && (
        <div style={{
          padding: '12px 18px',
          marginBottom: '20px',
          borderRadius: '12px',
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          fontSize: '0.9rem',
          fontWeight: '500',
          backgroundColor: syncMessage.type === 'success' ? '#e8f5e9' : '#ffebee',
          color: syncMessage.type === 'success' ? '#2e7d32' : '#c62828',
          border: `1px solid ${syncMessage.type === 'success' ? '#c8e6c9' : '#ffcdd2'}`
        }}>
          {syncMessage.type === 'success' ? <CheckCircle2 size={18} /> : <AlertCircle size={18} />}
          <span>{syncMessage.text}</span>
        </div>
      )}

      {/* 4 Summary Stat Cards Grid matching Dashboard */}
      <div className="summary-cards-grid">
        {[
          { title: 'โคเนื้อ (สศก. กลางประเทศ)', cat: 'โคพันธุ์ลูกผสม ขนาดกลาง' },
          { title: 'ลูกผสมบราห์มัน (>250-400 กก.)', cat: 'ลูกผสมบราห์มัน (>250-400 กก.)' },
          { title: 'ลูกผสมยุโรป (>250-400 กก.)', cat: 'ลูกผสมยุโรป (>250-400 กก.)' },
          { title: 'พื้นเมืองไทย (≤250 กก.)', cat: 'พื้นเมืองไทย (≤250 กก.)' },
        ].map((card, idx) => {
          const trend = getPriceTrendForCategory(card.cat);
          const isDown = trend === 'down';
          return (
            <div key={idx} className="summary-card">
              <div className="summary-info">
                <p>{card.title}</p>
                <h3>{getPriceForCategory(card.cat)}</h3>
              </div>
              <div className={`summary-icon ${isDown ? 'orange-icon' : 'green-icon'}`}>
                {isDown ? <TrendingDown size={24} /> : <TrendingUp size={24} />}
              </div>
            </div>
          );
        })}
      </div>

      {/* Main Table Card */}
      <div className="card">
        <div className="card-header">
          <div>
            <h2 className="card-title" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <TrendingUp size={22} style={{ color: 'var(--primary-color)' }} />
              ราคากลางปศุสัตว์รายสัปดาห์ (NABC AGRI API)
            </h2>
            <p style={{ margin: '4px 0 0 0', fontSize: '0.85rem', color: 'var(--text-muted)' }}>
              ดึงข้อมูลสดจาก agriapi.nabc.go.th พร้อมตัวกรองเลือกดูตามปี พ.ศ. และเดือน
            </p>
          </div>

          <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
            {/* Smart Image Dropzone Button */}
            <button
              className="btn btn-outline"
              onClick={() => setIsImageModalOpen(true)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                backgroundColor: '#f0fdf4',
                borderColor: '#86efac',
                color: '#166534'
              }}
            >
              <Sparkles size={16} style={{ color: '#16a34a' }} />
              อัปโหลดรูปรายงานปศุสัตว์ (OCR)
            </button>

            <button
              className="btn btn-outline"
              onClick={handleSyncLivePrice}
              disabled={syncing}
              style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
            >
              <RefreshCw size={15} style={{ animation: syncing ? 'spin 1s linear infinite' : 'none' }} />
              {syncing ? 'กำลังซิงก์ API...' : 'ซิงก์ NABC อัตโนมัติ'}
            </button>

            <button className="btn btn-primary" onClick={() => handleOpenModal()}>
              <Plus size={16} />
              บันทึกราคาสัปดาห์ใหม่
            </button>
          </div>
        </div>

        {/* View Mode Tabs & Year/Month Selection Bar */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          padding: '14px 24px',
          borderBottom: '1px solid var(--border-color)',
          backgroundColor: '#fff',
          flexWrap: 'wrap',
          gap: '12px'
        }}>
          {/* Mode Switcher */}
          <div style={{ display: 'flex', gap: '6px', backgroundColor: '#f1f5f9', padding: '4px', borderRadius: '8px' }}>
            <button
              onClick={() => { setViewMode('all'); setCurrentPage(1); }}
              style={{
                border: 'none',
                padding: '6px 14px',
                borderRadius: '6px',
                fontSize: '0.85rem',
                fontWeight: viewMode === 'all' ? '600' : '500',
                backgroundColor: viewMode === 'all' ? '#fff' : 'transparent',
                color: viewMode === 'all' ? 'var(--primary-color)' : 'var(--text-muted)',
                boxShadow: viewMode === 'all' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '6px'
              }}
            >
              <History size={15} />
              รายงานย้อนหลังทุกสัปดาห์ ({prices.length})
            </button>

            <button
              onClick={() => { setViewMode('latest'); setCurrentPage(1); }}
              style={{
                border: 'none',
                padding: '6px 14px',
                borderRadius: '6px',
                fontSize: '0.85rem',
                fontWeight: viewMode === 'latest' ? '600' : '500',
                backgroundColor: viewMode === 'latest' ? '#fff' : 'transparent',
                color: viewMode === 'latest' ? 'var(--primary-color)' : 'var(--text-muted)',
                boxShadow: viewMode === 'latest' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '6px'
              }}
            >
              <Tag size={15} />
              เฉพาะสัปดาห์ล่าสุด ({latestByCategory.length})
            </button>
          </div>

          {/* 📅 YEAR & MONTH SELECTION DROPDOWNS (CLEAN NAMES WITHOUT NUMBERS IN PARENTHESES) */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
            {/* Year Filter */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)', fontWeight: '500' }}>ปี พ.ศ.:</span>
              <select
                value={selectedYear}
                onChange={(e) => setSelectedYear(e.target.value)}
                style={{
                  padding: '7px 12px',
                  borderRadius: '8px',
                  border: '1px solid var(--border-color)',
                  backgroundColor: selectedYear !== 'all' ? '#e8f5e9' : '#fff',
                  color: selectedYear !== 'all' ? '#1b5e20' : 'var(--text-main)',
                  fontWeight: '600',
                  fontSize: '0.85rem'
                }}
              >
                <option value="all">ทุกปี</option>
                {availableYears.map((y) => (
                  <option key={y.value} value={y.value}>{y.label}</option>
                ))}
              </select>
            </div>

            {/* Month Filter (Clean Thai month names without numbers in parentheses) */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)', fontWeight: '500' }}>เดือน:</span>
              <select
                value={selectedMonth}
                onChange={(e) => setSelectedMonth(e.target.value)}
                style={{
                  padding: '7px 12px',
                  borderRadius: '8px',
                  border: '1px solid var(--border-color)',
                  backgroundColor: selectedMonth !== 'all' ? '#e8f5e9' : '#fff',
                  color: selectedMonth !== 'all' ? '#1b5e20' : 'var(--text-main)',
                  fontWeight: '600',
                  fontSize: '0.85rem'
                }}
              >
                <option value="all">ทุกเดือน</option>
                {thaiMonths.map((m) => (
                  <option key={m.value} value={m.value}>{m.name}</option>
                ))}
              </select>
            </div>

            {/* Clear Filter Button */}
            {(selectedYear !== 'all' || selectedMonth !== 'all') && (
              <button
                onClick={() => { setSelectedYear('all'); setSelectedMonth('all'); }}
                style={{
                  border: 'none',
                  backgroundColor: '#fee2e2',
                  color: '#991b1b',
                  padding: '6px 10px',
                  borderRadius: '6px',
                  fontSize: '0.78rem',
                  fontWeight: '600',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px'
                }}
              >
                <X size={14} />
                ล้างตัวกรอง
              </button>
            )}
          </div>
        </div>

        {/* Filter and Search Bar */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          padding: '14px 24px',
          flexWrap: 'wrap',
          gap: '16px',
          borderBottom: '1px solid var(--border-color)',
          backgroundColor: '#fafcfb'
        }}>
          <div style={{ display: 'flex', gap: '12px', flexGrow: 1, maxWidth: '700px', flexWrap: 'wrap' }}>
            <div className="search-box" style={{
              display: 'flex',
              alignItems: 'center',
              backgroundColor: '#fff',
              padding: '8px 12px',
              borderRadius: '8px',
              border: '1px solid var(--border-color)',
              width: '260px',
              flexGrow: 1,
              maxWidth: '350px'
            }}>
              <Search size={18} style={{ color: '#9ca3af', marginRight: '8px' }} />
              <input
                type="text"
                placeholder="ค้นหาหมวดหมู่, วันที่, หมายเหตุ..."
                style={{ border: 'none', backgroundColor: 'transparent', outline: 'none', width: '100%', fontSize: '0.875rem' }}
                value={searchTerm}
                onChange={(e) => { setSearchTerm(e.target.value); setCurrentPage(1); }}
              />
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ fontSize: '0.82rem', color: 'var(--text-muted)' }}>เรียงลำดับ:</span>
            <select
              value={sortOrder}
              onChange={(e) => setSortOrder(e.target.value)}
              style={{
                padding: '8px 12px',
                borderRadius: '8px',
                border: '1px solid var(--border-color)',
                backgroundColor: '#fff',
                color: 'var(--text-main)',
                fontSize: '0.875rem'
              }}
            >
              <option value="newest_date">สัปดาห์: ล่าสุด ➔ เก่า</option>
              <option value="oldest_date">สัปดาห์: เก่า ➔ ล่าสุด</option>
              <option value="price_high">ราคา: สูง ➔ ต่ำ</option>
              <option value="price_low">ราคา: ต่ำ ➔ สูง</option>
            </select>
          </div>
        </div>

        {/* Table Content */}
        {loading ? (
          <p style={{ padding: '36px', textAlign: 'center', color: 'var(--text-muted)' }}>กำลังโหลดข้อมูลราคากลางรายสัปดาห์...</p>
        ) : (
          <>
            <div className="table-container">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>รอบสัปดาห์ (วันที่มีผล)</th>
                    <th>สายพันธุ์ / พิกัดน้ำหนัก</th>
                    <th>ราคาเฉลี่ย (บาท/กก.)</th>
                    <th>แหล่งที่มาอ้างอิง</th>
                    <th>รายละเอียดรอบรายงาน</th>
                    <th style={{ textAlign: 'center' }}>จัดการ</th>
                  </tr>
                </thead>
                <tbody>
                  {currentItems.length > 0 ? (
                    currentItems.map((item) => (
                      <tr key={item.id}>
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--text-main)', fontWeight: '600', fontSize: '0.875rem' }}>
                            <Calendar size={15} style={{ color: 'var(--primary-color)' }} />
                            <span>{formatThaiDate(item.effective_date)}</span>
                          </div>
                        </td>
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontWeight: '550' }}>
                            <Tag size={15} style={{ color: 'var(--text-muted)' }} />
                            <span>{item.category || 'ทั่วไป'}</span>
                          </div>
                        </td>
                        <td>
                          <span style={{
                            fontWeight: '700',
                            fontSize: '0.95rem',
                            color: 'var(--primary-color)',
                            backgroundColor: 'var(--primary-light)',
                            padding: '4px 10px',
                            borderRadius: '6px'
                          }}>
                            {parseFloat(item.price_per_kg).toFixed(2)} ฿
                          </span>
                        </td>
                        <td>
                          <span style={{
                            display: 'inline-block',
                            padding: '3px 8px',
                            borderRadius: '6px',
                            fontSize: '0.75rem',
                            fontWeight: '500',
                            backgroundColor: '#f1f5f9',
                            color: '#334155',
                            border: '1px solid #e2e8f0'
                          }}>
                            {item.source || 'NABC AGRI API'}
                          </span>
                        </td>
                        <td style={{ color: 'var(--text-muted)', fontSize: '0.8rem', maxWidth: '260px' }}>
                          {item.note || '-'}
                        </td>
                        <td>
                          <div className="action-links" style={{ justifyContent: 'center' }}>
                            <button className="action-btn edit" title="แก้ไข" onClick={() => handleOpenModal(item)}>
                              <Edit size={16} />
                            </button>
                            <button className="action-btn delete" title="ลบ" onClick={() => handleDelete(item.id, item.category)}>
                              <Trash2 size={16} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan="6" style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>
                        ไม่พบรายการราคาตลาดกลางในเดือน/ปีที่เลือก
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
              totalItems={filteredPrices.length}
              itemsPerPage={itemsPerPage}
            />
          </>
        )}
      </div>

      {/* 📷 SMART IMAGE DROPZONE & OCR MODAL */}
      {isImageModalOpen && (
        <div className="modal-overlay" onClick={() => setIsImageModalOpen(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '650px' }}>
            <div className="modal-header">
              <h3 className="modal-title" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Sparkles size={20} style={{ color: '#16a34a' }} />
                อัปโหลดรูปภาพรายงานราคาปศุสัตว์ (Smart OCR)
              </h3>
              <button className="modal-close" onClick={() => setIsImageModalOpen(false)}>&times;</button>
            </div>

            <div className="modal-body" style={{ padding: '20px 24px' }}>
              <p style={{ margin: '0 0 16px 0', fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                ลากรูปภาพอินโฟกราฟิกรายงานราคาของกรมปศุสัตว์มาวาง ระบบจะอ่านตัวเลขราคาของแต่ละสายพันธุ์ลงตารางให้อัตโนมัติ
              </p>

              {/* Dropzone Area */}
              <div
                onDragOver={(e) => e.preventDefault()}
                onDrop={handleDrop}
                onClick={() => fileInputRef.current?.click()}
                style={{
                  border: '2px dashed var(--border-color)',
                  borderRadius: '12px',
                  padding: '24px',
                  textAlign: 'center',
                  cursor: 'pointer',
                  backgroundColor: previewUrl ? '#fafcfb' : '#f8faf9',
                  transition: 'all 0.2s ease',
                  marginBottom: '16px'
                }}
              >
                <input
                  type="file"
                  ref={fileInputRef}
                  style={{ display: 'none' }}
                  accept="image/*"
                  onChange={(e) => e.target.files && handleFileSelect(e.target.files[0])}
                />

                {previewUrl ? (
                  <div>
                    <img
                      src={previewUrl}
                      alt="Report Preview"
                      style={{ maxHeight: '180px', maxWidth: '100%', borderRadius: '8px', objectFit: 'contain', margin: '0 auto 10px auto', display: 'block' }}
                    />
                    <span style={{ fontSize: '0.82rem', color: '#166534', fontWeight: '600' }}>
                      ✓ เลือกรูปภาพแล้ว: {selectedFile?.name} (คลิกเพื่อเปลี่ยนรูป)
                    </span>
                  </div>
                ) : (
                  <div>
                    <Upload size={36} style={{ color: 'var(--text-muted)', margin: '0 auto 8px auto' }} />
                    <div style={{ fontWeight: '600', fontSize: '0.9rem', color: 'var(--text-main)' }}>
                      ลากรูปภาพรายงานมาวางที่นี่ หรือคลิกเพื่อเลือกไฟล์
                    </div>
                    <span style={{ fontSize: '0.78rem', color: 'var(--text-muted)', display: 'block', marginTop: '4px' }}>
                      รองรับไฟล์ภาพ PNG, JPG, JPEG (ขนาดไม่เกิน 10MB)
                    </span>
                  </div>
                )}
              </div>

              {/* Scan Button */}
              {selectedFile && !extractedData && (
                <div style={{ textAlign: 'center', marginBottom: '16px' }}>
                  <button
                    className="btn btn-primary"
                    onClick={handleScanImage}
                    disabled={parsingImage}
                    style={{ padding: '10px 24px', fontSize: '0.9rem' }}
                  >
                    <Sparkles size={16} />
                    {parsingImage ? 'กำลังอ่านตัวเลขจากรูปภาพ...' : 'เริ่มสแกนอ่านตัวเลขราคาจากภาพ'}
                  </button>
                </div>
              )}

              {/* Extracted Data Table Preview */}
              {extractedData && (
                <div style={{ marginTop: '16px' }}>
                  <div style={{
                    padding: '10px 14px',
                    borderRadius: '8px',
                    backgroundColor: '#e8f5e9',
                    border: '1px solid #c8e6c9',
                    fontSize: '0.85rem',
                    fontWeight: '600',
                    color: '#2e7d32',
                    marginBottom: '12px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px'
                  }}>
                    <Check size={16} />
                    <span>อ่านข้อมูลสำเร็จ: {extractedData.report_title}</span>
                  </div>

                  {/* Effective Date Selector */}
                  <div style={{
                    padding: '10px 14px',
                    backgroundColor: '#f8fafc',
                    border: '1px solid #e2e8f0',
                    borderRadius: '8px',
                    marginBottom: '12px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: '12px'
                  }}>
                    <div>
                      <label style={{ fontSize: '0.82rem', fontWeight: '700', color: 'var(--text-main)', display: 'block' }}>
                        📅 วันที่ของราคา (Effective Date):
                      </label>
                      <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                        ตรงตามข้อความ "(รายงาน ณ วันที่ ...)" มุมบนขวาของรูปภาพ ({extractedData.report_date_text || '17 สิงหาคม 2569'})
                      </span>
                    </div>
                    <input
                      type="date"
                      value={extractedData.effective_date || extractedData.items[0]?.effective_date || ''}
                      onChange={(e) => handleBatchDateChange(e.target.value)}
                      style={{
                        padding: '6px 12px',
                        borderRadius: '6px',
                        border: '1px solid var(--border-color)',
                        fontSize: '0.85rem',
                        fontWeight: '600',
                        color: 'var(--text-main)',
                        backgroundColor: '#fff'
                      }}
                    />
                  </div>

                  <div style={{ maxHeight: '220px', overflowY: 'auto', border: '1px solid var(--border-color)', borderRadius: '8px' }}>
                    <table className="data-table" style={{ fontSize: '0.82rem' }}>
                      <thead>
                        <tr>
                          <th>สายพันธุ์ / พิกัดน้ำหนัก</th>
                          <th style={{ width: '120px' }}>วันที่บันทึก</th>
                          <th style={{ width: '130px' }}>ราคา (บาท/กก.)</th>
                        </tr>
                      </thead>
                      <tbody>
                        {extractedData.items.map((item, idx) => (
                          <tr key={idx}>
                            <td style={{ fontWeight: '500' }}>{item.category}</td>
                            <td>
                              <span style={{
                                display: 'inline-block',
                                padding: '2px 8px',
                                borderRadius: '4px',
                                backgroundColor: '#f1f5f9',
                                color: '#475569',
                                fontSize: '0.75rem',
                                fontWeight: '600'
                              }}>
                                {item.effective_date}
                              </span>
                            </td>
                            <td>
                              <input
                                type="number"
                                step="0.01"
                                value={item.price_per_kg}
                                onChange={(e) => handleExtractedPriceChange(idx, e.target.value)}
                                style={{
                                  width: '100%',
                                  padding: '4px 8px',
                                  borderRadius: '6px',
                                  border: '1px solid var(--border-color)',
                                  fontWeight: '700',
                                  color: 'var(--primary-color)'
                                }}
                              />
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </div>

            <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', padding: '16px 24px', borderTop: '1px solid var(--border-color)' }}>
              <button
                type="button"
                className="btn btn-outline"
                onClick={() => setIsImageModalOpen(false)}
              >
                ยกเลิก
              </button>
              {extractedData && (
                <button
                  type="button"
                  className="btn btn-primary"
                  onClick={handleSaveBatchPrices}
                  disabled={savingBatch}
                  style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
                >
                  <Check size={16} />
                  {savingBatch ? 'กำลังบันทึก...' : 'ยืนยันบันทึกทุกรายการลงระบบ'}
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Manual Single Add / Edit Modal */}
      {isModalOpen && (
        <div className="modal-overlay" onClick={handleCloseModal}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '480px' }}>
            <div className="modal-header">
              <h3 className="modal-title">
                {isEditing ? 'แก้ไขราคาตลาดกลางรายสัปดาห์' : 'บันทึกราคากลางรอบสัปดาห์ใหม่'}
              </h3>
              <button className="modal-close" onClick={handleCloseModal}>&times;</button>
            </div>
            
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label" htmlFor="category">สายพันธุ์ / พิกัดน้ำหนัก *</label>
                  <input
                    id="category"
                    name="category"
                    type="text"
                    className="form-control"
                    placeholder="เช่น โคพันธุ์ลูกผสม ขนาดกลาง"
                    value={currentPrice.category}
                    onChange={handleChange}
                    required
                  />
                </div>

                <div className="form-group">
                  <label className="form-label" htmlFor="price_per_kg">ราคาเฉลี่ย (บาท/กก.) *</label>
                  <input
                    id="price_per_kg"
                    name="price_per_kg"
                    type="number"
                    step="0.01"
                    className="form-control"
                    placeholder="เช่น 95.43"
                    value={currentPrice.price_per_kg}
                    onChange={handleChange}
                    required
                  />
                </div>

                <div className="form-group">
                  <label className="form-label" htmlFor="effective_date">รอบสัปดาห์ (วันที่มีผล) *</label>
                  <input
                    id="effective_date"
                    name="effective_date"
                    type="date"
                    className="form-control"
                    value={currentPrice.effective_date}
                    onChange={handleChange}
                    required
                  />
                </div>

                <div className="form-group">
                  <label className="form-label" htmlFor="source">แหล่งที่มาอ้างอิง</label>
                  <input
                    id="source"
                    name="source"
                    type="text"
                    className="form-control"
                    placeholder="เช่น NABC AGRI API (agriapi.nabc.go.th)"
                    value={currentPrice.source}
                    onChange={handleChange}
                  />
                </div>

                <div className="form-group">
                  <label className="form-label" htmlFor="note">รายละเอียดรอบรายงาน</label>
                  <textarea
                    id="note"
                    name="note"
                    rows="2"
                    className="form-control"
                    placeholder="เช่น สัปดาห์ที่ 4 เดือน 07/2569"
                    value={currentPrice.note}
                    onChange={handleChange}
                  />
                </div>
              </div>

              <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', padding: '16px 24px', borderTop: '1px solid var(--border-color)' }}>
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
    </div>
  );
};

export default MarketPrices;
