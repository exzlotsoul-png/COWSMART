import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './contexts/AuthContext';
import AdminLayout from './components/layout/AdminLayout';
import Login from './pages/Login';

import Breeds from './pages/Breeds';
import CowTypes from './pages/CowTypes';

import Diseases from './pages/Diseases';
import Medicines from './pages/Medicines';
import Vaccines from './pages/Vaccines';
import CheckupTypes from './pages/CheckupTypes';
import Users from './pages/Users';
import IssueReports from './pages/IssueReports';
import Units from './pages/Units';
import Settings from './pages/Settings';
import Dashboard from './pages/Dashboard';

function App() {
  return (
    <AuthProvider>
      <Router>
        <Routes>
          <Route path="/login" element={<Login />} />
          
          <Route path="/" element={<AdminLayout />}>
            <Route index element={<Dashboard />} />
            <Route path="users" element={<Users />} />
            <Route path="breeds" element={<Breeds />} />
            <Route path="cow-types" element={<CowTypes />} />
            <Route path="diseases" element={<Diseases />} />
            <Route path="medicines" element={<Medicines />} />
            <Route path="vaccines" element={<Vaccines />} />
            <Route path="checkup-types" element={<CheckupTypes />} />
            <Route path="issue-reports" element={<IssueReports />} />
            <Route path="units" element={<Units />} />
            <Route path="settings" element={<Settings />} />
          </Route>
        </Routes>
      </Router>
    </AuthProvider>
  );
}

export default App;
