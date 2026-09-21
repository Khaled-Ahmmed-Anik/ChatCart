import { Navigate, Route, Routes } from "react-router-dom";
import { ProtectedRoute } from "../auth/ProtectedRoute";
import { AppShell } from "../components/layout/AppShell";
import { LoginPage } from "../pages/LoginPage";
import { BusinessesPage } from "../pages/admin/BusinessesPage";
import { AnalyticsPage } from "../pages/business/AnalyticsPage";
import { ConversationsPage } from "../pages/business/ConversationsPage";
import { OrdersPage } from "../pages/business/OrdersPage";
import { ProductsPage } from "../pages/business/ProductsPage";
import { SettingsPage } from "../pages/business/SettingsPage";
import { DataDeletionPage } from "../pages/legal/DataDeletionPage";
import { PrivacyPolicyPage } from "../pages/legal/PrivacyPolicyPage";

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/privacy" element={<PrivacyPolicyPage />} />
      <Route path="/data-deletion" element={<DataDeletionPage />} />
      <Route element={<ProtectedRoute><AppShell /></ProtectedRoute>}>
        <Route path="/admin/businesses" element={<ProtectedRoute actorType="platform_administrator"><BusinessesPage /></ProtectedRoute>} />
        <Route path="/app" element={<ProtectedRoute actorType="business_user"><AnalyticsPage /></ProtectedRoute>} />
        <Route path="/app/orders" element={<ProtectedRoute actorType="business_user"><OrdersPage /></ProtectedRoute>} />
        <Route path="/app/conversations" element={<ProtectedRoute actorType="business_user"><ConversationsPage /></ProtectedRoute>} />
        <Route path="/app/products" element={<ProtectedRoute actorType="business_user"><ProductsPage /></ProtectedRoute>} />
        <Route path="/app/settings" element={<ProtectedRoute actorType="business_user"><SettingsPage /></ProtectedRoute>} />
      </Route>
      <Route path="*" element={<Navigate to="/login" replace />} />
    </Routes>
  );
}
