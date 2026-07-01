import React, { useState, useEffect } from 'react';
import { Save } from 'lucide-react';
import api from '../lib/axios';

const Settings = () => {
  const [gestationDays, setGestationDays] = useState('283'); // Default 283 days
  const [settingId, setSettingId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    fetchSettings();
  }, []);

  const fetchSettings = async () => {
    try {
      const response = await api.get('/settings');
      const settingsList = response.data.data || response.data;
      
      const gestationSetting = settingsList.find(s => s.setting_key === 'gestation_days');
      if (gestationSetting) {
        setGestationDays(gestationSetting.setting_value);
        setSettingId(gestationSetting.setting_id);
      }
    } catch (error) {
      console.error("Error fetching settings:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    setMessage('');
    
    try {
      if (settingId) {
        await api.put(`/settings/${settingId}`, {
          setting_key: 'gestation_days',
          setting_value: gestationDays,
          description: 'ระยะเวลาตั้งท้องเฉลี่ยของวัว (วัน) ใช้สำหรับคำนวณวันคลอดโดยประมาณ'
        });
      } else {
        const response = await api.post('/settings', {
          setting_key: 'gestation_days',
          setting_value: gestationDays,
          description: 'ระยะเวลาตั้งท้องเฉลี่ยของวัว (วัน) ใช้สำหรับคำนวณวันคลอดโดยประมาณ'
        });
        setSettingId(response.data.setting_id || response.data.id);
      }
      setMessage('บันทึกการตั้งค่าเรียบร้อยแล้ว');
      setTimeout(() => setMessage(''), 3000);
    } catch (error) {
      console.error("Error saving setting:", error);
      setMessage('เกิดข้อผิดพลาดในการบันทึกข้อมูล');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div>
      <div className="card" style={{ maxWidth: '700px', margin: '0 auto' }}>
        <div className="card-header">
          <h2 className="card-title">กำหนดการคำนวณวันคลอด</h2>
        </div>

        {loading ? (
          <p style={{ padding: '24px' }}>กำลังโหลดข้อมูล...</p>
        ) : (
          <form onSubmit={handleSave} style={{ padding: '24px' }}>
            {message && (
              <div style={{ 
                padding: '10px 15px', 
                marginBottom: '20px', 
                borderRadius: '8px', 
                backgroundColor: message.includes('เรียบร้อย') ? '#d1fae5' : '#fee2e2',
                color: message.includes('เรียบร้อย') ? '#065f46' : '#991b1b'
              }}>
                {message}
              </div>
            )}
            
            <div className="form-group">
              <label className="form-label" htmlFor="gestation_days">
                ระยะเวลาตั้งท้องเฉลี่ย (จำนวนวัน)
              </label>
              <p style={{ color: '#6b7280', fontSize: '0.875rem', marginBottom: '10px' }}>
                ตัวเลขนี้จะถูกนำไปบวกกับวันที่ผสมพันธุ์ เพื่อคาดการณ์วันที่วัวจะคลอดลูก (ค่าเฉลี่ยมาตรฐานคือ 283 วัน)
              </p>
              <input 
                id="gestation_days" 
                name="gestation_days" 
                type="number" 
                min="1"
                max="400"
                className="form-control" 
                value={gestationDays} 
                onChange={(e) => setGestationDays(e.target.value)} 
                required 
              />
            </div>
            
            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '20px' }}>
              <button type="submit" className="btn btn-primary" disabled={saving}>
                {saving ? 'กำลังบันทึก...' : (
                  <>
                    <Save size={16} /> บันทึกการตั้งค่า
                  </>
                )}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

export default Settings;
