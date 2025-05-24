-- Seed data for development and testing

-- Insert sample changelog entries
INSERT INTO changelog_entries (title, content, version, module_slug, is_published, published_at) VALUES
('Platform Launch', 'Welcome to Novaly! Our multi-tenant SaaS platform is now live with core features including user management, messaging, and module system.', '1.0.0', 'core', true, NOW() - INTERVAL '7 days'),
('Health & Safety Module', 'New Health & Safety module now available! Track hazards, manage incidents, and ensure workplace compliance.', '1.0.0', 'health-safety', true, NOW() - INTERVAL '5 days'),
('Task Management Module', 'Organize your work with our new Task Management module. Create projects, assign tasks, and track progress.', '1.0.0', 'tasks', true, NOW() - INTERVAL '3 days'),
('Real-time Messaging', 'Enhanced messaging system with real-time updates, file sharing, and conversation management.', '1.1.0', 'messaging', true, NOW() - INTERVAL '1 day');

-- Insert sample bug report for demonstration (will be associated with companies after user signup)
-- This is just to show the structure - actual data will be created when users sign up

-- Insert sample feature requests for demonstration
-- This is just to show the structure - actual data will be created when users sign up

-- Refresh the platform metrics view (non-concurrent for initial setup)
REFRESH MATERIALIZED VIEW vw_platform_metrics;
