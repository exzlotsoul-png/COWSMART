import React, { createContext, useContext, useState, useCallback, useRef } from 'react';
import { AlertTriangle } from 'lucide-react';

const ConfirmModalContext = createContext(null);

export const ConfirmModalProvider = ({ children }) => {
  const [modalState, setModalState] = useState({
    isOpen: false,
    title: 'ยืนยันการลบข้อมูล',
    message: '',
    itemName: '',
    itemType: '',
    description: 'การดำเนินการนี้ไม่สามารถย้อนกลับได้ และข้อมูลจะถูกลบออกจากระบบอย่างถาวร',
    confirmText: 'ยืนยันการลบ',
    cancelText: 'ยกเลิก',
    isDeleting: false,
  });

  const resolverRef = useRef(null);

  const confirmDelete = useCallback(({
    title = 'ยืนยันการลบข้อมูล',
    message = '',
    itemName = '',
    itemType = 'ข้อมูล',
    description = 'การดำเนินการนี้ไม่สามารถย้อนกลับได้ และข้อมูลจะถูกลบออกจากระบบอย่างถาวร',
    confirmText = 'ยืนยันการลบ',
    cancelText = 'ยกเลิก',
    onConfirm = null,
  }) => {
    return new Promise((resolve) => {
      resolverRef.current = { resolve, onConfirm };
      setModalState({
        isOpen: true,
        title,
        message,
        itemName,
        itemType,
        description,
        confirmText,
        cancelText,
        isDeleting: false,
      });
    });
  }, []);

  const handleClose = useCallback(() => {
    if (modalState.isDeleting) return;
    if (resolverRef.current) {
      resolverRef.current.resolve(false);
      resolverRef.current = null;
    }
    setModalState((prev) => ({ ...prev, isOpen: false }));
  }, [modalState.isDeleting]);

  const handleConfirm = useCallback(async () => {
    if (resolverRef.current?.onConfirm) {
      try {
        setModalState((prev) => ({ ...prev, isDeleting: true }));
        await resolverRef.current.onConfirm();
        resolverRef.current.resolve(true);
      } catch (err) {
        resolverRef.current.resolve(false);
        throw err;
      } finally {
        resolverRef.current = null;
        setModalState((prev) => ({ ...prev, isOpen: false, isDeleting: false }));
      }
    } else {
      if (resolverRef.current) {
        resolverRef.current.resolve(true);
        resolverRef.current = null;
      }
      setModalState((prev) => ({ ...prev, isOpen: false }));
    }
  }, []);

  return (
    <ConfirmModalContext.Provider value={{ confirmDelete }}>
      {children}

      {modalState.isOpen && (
        <div className="modal-overlay" onClick={handleClose} style={{ zIndex: 9999 }}>
          <div
            className="modal-content"
            onClick={(e) => e.stopPropagation()}
            style={{ maxWidth: '440px' }}
          >
            <div className="modal-header">
              <h3
                className="modal-title"
                style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#dc2626' }}
              >
                <AlertTriangle size={20} color="#dc2626" />
                {modalState.title}
              </h3>
              <button
                type="button"
                className="modal-close"
                onClick={handleClose}
                disabled={modalState.isDeleting}
              >
                &times;
              </button>
            </div>

            <div
              className="modal-body"
              style={{ fontSize: '0.9rem', color: 'var(--text-main)', lineHeight: '1.6' }}
            >
              {modalState.message ? (
                modalState.message
              ) : (
                <>
                  คุณแน่ใจหรือไม่ที่จะลบ{modalState.itemType}{' '}
                  {modalState.itemName ? <strong>"{modalState.itemName}"</strong> : ''}{' '}
                  ออกจากระบบฐานข้อมูล?
                </>
              )}
              {modalState.description && (
                <div style={{ marginTop: '8px', fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                  {modalState.description}
                </div>
              )}
            </div>

            <div className="modal-footer" style={{ marginTop: '18px' }}>
              <button
                type="button"
                className="btn btn-outline"
                onClick={handleClose}
                disabled={modalState.isDeleting}
              >
                {modalState.cancelText}
              </button>
              <button
                type="button"
                className="btn btn-primary"
                onClick={handleConfirm}
                disabled={modalState.isDeleting}
                style={{ backgroundColor: '#dc2626', borderColor: '#dc2626' }}
              >
                {modalState.isDeleting ? 'กำลังลบ...' : modalState.confirmText}
              </button>
            </div>
          </div>
        </div>
      )}
    </ConfirmModalContext.Provider>
  );
};

export const useConfirmModal = () => {
  const context = useContext(ConfirmModalContext);
  if (!context) {
    throw new Error('useConfirmModal must be used within a ConfirmModalProvider');
  }
  return context;
};
