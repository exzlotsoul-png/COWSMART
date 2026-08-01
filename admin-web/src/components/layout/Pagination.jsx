import React from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';

const Pagination = ({ currentPage, totalPages, onPageChange, totalItems, itemsPerPage }) => {
  const safeTotalPages = Math.max(1, totalPages || 1);
  const startItem = totalItems === 0 ? 0 : (currentPage - 1) * itemsPerPage + 1;
  const endItem = Math.min(currentPage * itemsPerPage, totalItems);

  // Generate page numbers to show (e.g. 1, 2, 3...)
  const getPageNumbers = () => {
    const pages = [];
    const maxVisiblePages = 5;

    if (safeTotalPages <= maxVisiblePages) {
      for (let i = 1; i <= safeTotalPages; i++) {
        pages.push(i);
      }
    } else {
      // Always show page 1
      pages.push(1);

      let start = Math.max(2, currentPage - 1);
      let end = Math.min(safeTotalPages - 1, currentPage + 1);

      if (currentPage <= 2) {
        end = 4;
      } else if (currentPage >= safeTotalPages - 1) {
        start = safeTotalPages - 3;
      }

      if (start > 2) {
        pages.push('...');
      }

      for (let i = start; i <= end; i++) {
        pages.push(i);
      }

      if (end < safeTotalPages - 1) {
        pages.push('...');
      }

      // Always show last page
      pages.push(safeTotalPages);
    }
    return pages;
  };

  return (
    <div className="pagination-container">
      <div className="pagination-info">
        แสดง {startItem}-{endItem} จากทั้งหมด {totalItems} รายการ
      </div>
      <div className="pagination-buttons">
        <button
          className="pagination-btn pagination-arrow"
          onClick={() => onPageChange(currentPage - 1)}
          disabled={currentPage <= 1}
        >
          <ChevronLeft size={16} style={{ marginRight: '4px' }} />
          ก่อนหน้า
        </button>

        {getPageNumbers().map((page, idx) => (
          <button
            key={idx}
            className={`pagination-btn ${page === currentPage ? 'active' : ''}`}
            onClick={() => typeof page === 'number' && onPageChange(page)}
            disabled={page === '...'}
          >
            {page}
          </button>
        ))}

        <button
          className="pagination-btn pagination-arrow"
          onClick={() => onPageChange(currentPage + 1)}
          disabled={currentPage >= safeTotalPages}
        >
          ถัดไป
          <ChevronRight size={16} style={{ marginLeft: '4px' }} />
        </button>
      </div>
    </div>
  );
};

export default Pagination;
