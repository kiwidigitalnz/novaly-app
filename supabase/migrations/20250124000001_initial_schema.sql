-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create custom types
CREATE TYPE user_role AS ENUM ('admin', 'user', 'super_admin');
CREATE TYPE company_status AS ENUM ('active', 'trial', 'delinquent', 'suspended');
CREATE TYPE subscription_status AS ENUM ('active', 'past_due', 'canceled', 'unpaid');

-- Companies table (tenants)
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    logo_url TEXT,
    stripe_customer_id TEXT UNIQUE,
    status company_status DEFAULT 'trial',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    delinquent_at TIMESTAMPTZ,
    
    -- Constraints
    CONSTRAINT companies_slug_format CHECK (slug ~ '^[a-z0-9-]+$'),
    CONSTRAINT companies_name_length CHECK (length(name) >= 2 AND length(name) <= 100)
);

-- Create index for performance
CREATE INDEX idx_companies_slug ON companies(slug);
CREATE INDEX idx_companies_status ON companies(status);
CREATE INDEX idx_companies_stripe_customer ON companies(stripe_customer_id);

-- Users table (extends Supabase auth.users)
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email CITEXT NOT NULL,
    name TEXT,
    avatar_url TEXT,
    default_company_id UUID REFERENCES companies(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT user_profiles_name_length CHECK (length(name) >= 1 AND length(name) <= 100)
);

-- Create index for performance
CREATE INDEX idx_user_profiles_email ON user_profiles(email);
CREATE INDEX idx_user_profiles_default_company ON user_profiles(default_company_id);

-- Company members (many-to-many relationship)
CREATE TABLE company_members (
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    role user_role DEFAULT 'user',
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (user_id, company_id)
);

-- Create indexes for performance
CREATE INDEX idx_company_members_company ON company_members(company_id);
CREATE INDEX idx_company_members_user ON company_members(user_id);
CREATE INDEX idx_company_members_role ON company_members(role);

-- Invitations table
CREATE TABLE invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    email CITEXT NOT NULL,
    role user_role DEFAULT 'user',
    token TEXT UNIQUE NOT NULL,
    invited_by UUID REFERENCES user_profiles(id),
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT invitations_expires_future CHECK (expires_at > created_at)
);

-- Create indexes for performance
CREATE INDEX idx_invitations_token ON invitations(token);
CREATE INDEX idx_invitations_company ON invitations(company_id);
CREATE INDEX idx_invitations_email ON invitations(email);
CREATE INDEX idx_invitations_expires ON invitations(expires_at);

-- Modules catalog
CREATE TABLE modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    latest_version TEXT NOT NULL,
    base_price_cents INTEGER DEFAULT 0,
    per_user_price_cents INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    is_beta BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT modules_slug_format CHECK (slug ~ '^[a-z0-9-]+$'),
    CONSTRAINT modules_price_positive CHECK (base_price_cents >= 0 AND per_user_price_cents >= 0)
);

-- Create index for performance
CREATE INDEX idx_modules_slug ON modules(slug);
CREATE INDEX idx_modules_active ON modules(is_active);

-- Company modules (enabled modules per company)
CREATE TABLE company_modules (
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    module_id UUID REFERENCES modules(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT true,
    enabled_at TIMESTAMPTZ DEFAULT NOW(),
    billing_plan TEXT,
    settings JSONB DEFAULT '{}',
    
    PRIMARY KEY (company_id, module_id)
);

-- Create indexes for performance
CREATE INDEX idx_company_modules_company ON company_modules(company_id);
CREATE INDEX idx_company_modules_enabled ON company_modules(enabled);

-- Subscriptions table
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    stripe_subscription_id TEXT UNIQUE NOT NULL,
    status subscription_status NOT NULL,
    current_period_start TIMESTAMPTZ NOT NULL,
    current_period_end TIMESTAMPTZ NOT NULL,
    cancel_at_period_end BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_subscriptions_company ON subscriptions(company_id);
CREATE INDEX idx_subscriptions_stripe ON subscriptions(stripe_subscription_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);

-- Permissions table
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_slug TEXT NOT NULL,
    role user_role NOT NULL,
    action TEXT NOT NULL,
    resource TEXT DEFAULT '*',
    
    UNIQUE(module_slug, role, action, resource)
);

-- Create index for performance
CREATE INDEX idx_permissions_lookup ON permissions(module_slug, role);

-- Notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT,
    payload JSONB DEFAULT '{}',
    seen BOOLEAN DEFAULT false,
    delivered_channels TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT notifications_type_format CHECK (type ~ '^[a-z0-9_.]+$')
);

-- Create indexes for performance
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_company ON notifications(company_id);
CREATE INDEX idx_notifications_seen ON notifications(seen);
CREATE INDEX idx_notifications_created ON notifications(created_at);

-- Activity log table
CREATE TABLE activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    user_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id UUID,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT activity_log_action_format CHECK (action ~ '^[a-z0-9_.]+$')
);

-- Create indexes for performance
CREATE INDEX idx_activity_log_company ON activity_log(company_id);
CREATE INDEX idx_activity_log_user ON activity_log(user_id);
CREATE INDEX idx_activity_log_created ON activity_log(created_at);
CREATE INDEX idx_activity_log_resource ON activity_log(resource_type, resource_id);

-- Conversations table (for messaging)
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name TEXT,
    is_group BOOLEAN DEFAULT false,
    created_by UUID REFERENCES user_profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_conversations_company ON conversations(company_id);
CREATE INDEX idx_conversations_created_by ON conversations(created_by);

-- Conversation members
CREATE TABLE conversation_members (
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    last_read_at TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (conversation_id, user_id)
);

-- Create indexes for performance
CREATE INDEX idx_conversation_members_conversation ON conversation_members(conversation_id);
CREATE INDEX idx_conversation_members_user ON conversation_members(user_id);

-- Messages table
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT messages_content_length CHECK (length(content) >= 1 AND length(content) <= 4000)
);

-- Create indexes for performance
CREATE INDEX idx_messages_conversation ON messages(conversation_id);
CREATE INDEX idx_messages_user ON messages(user_id);
CREATE INDEX idx_messages_created ON messages(created_at);

-- Integrations table (for storing OAuth tokens and settings)
CREATE TABLE integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    provider_account_id TEXT,
    access_token TEXT, -- encrypted
    refresh_token TEXT, -- encrypted
    expires_at TIMESTAMPTZ,
    settings JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(company_id, provider, provider_account_id)
);

-- Create indexes for performance
CREATE INDEX idx_integrations_company ON integrations(company_id);
CREATE INDEX idx_integrations_provider ON integrations(provider);
CREATE INDEX idx_integrations_active ON integrations(is_active);

-- Bug reports table
CREATE TABLE bug_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    severity TEXT DEFAULT 'medium',
    status TEXT DEFAULT 'open',
    module_slug TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT bug_reports_severity_valid CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    CONSTRAINT bug_reports_status_valid CHECK (status IN ('open', 'in_progress', 'resolved', 'closed'))
);

-- Create indexes for performance
CREATE INDEX idx_bug_reports_company ON bug_reports(company_id);
CREATE INDEX idx_bug_reports_user ON bug_reports(user_id);
CREATE INDEX idx_bug_reports_status ON bug_reports(status);
CREATE INDEX idx_bug_reports_module ON bug_reports(module_slug);

-- Feature requests table
CREATE TABLE feature_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    priority TEXT DEFAULT 'medium',
    status TEXT DEFAULT 'submitted',
    module_slug TEXT,
    votes INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT feature_requests_priority_valid CHECK (priority IN ('low', 'medium', 'high')),
    CONSTRAINT feature_requests_status_valid CHECK (status IN ('submitted', 'planned', 'in_dev', 'beta', 'released', 'rejected'))
);

-- Create indexes for performance
CREATE INDEX idx_feature_requests_company ON feature_requests(company_id);
CREATE INDEX idx_feature_requests_user ON feature_requests(user_id);
CREATE INDEX idx_feature_requests_status ON feature_requests(status);
CREATE INDEX idx_feature_requests_votes ON feature_requests(votes);

-- Changelog entries table
CREATE TABLE changelog_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    version TEXT,
    module_slug TEXT,
    is_published BOOLEAN DEFAULT false,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_changelog_published ON changelog_entries(is_published, published_at);
CREATE INDEX idx_changelog_module ON changelog_entries(module_slug);

-- Events table (for event bus)
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    
    -- Constraints
    CONSTRAINT events_type_format CHECK (event_type ~ '^[a-z0-9_.]+$')
);

-- Create indexes for performance
CREATE INDEX idx_events_company ON events(company_id);
CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_events_created ON events(created_at);
CREATE INDEX idx_events_processed ON events(processed_at);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers to relevant tables
CREATE TRIGGER update_companies_updated_at BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_modules_updated_at BEFORE UPDATE ON modules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_conversations_updated_at BEFORE UPDATE ON conversations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_messages_updated_at BEFORE UPDATE ON messages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_integrations_updated_at BEFORE UPDATE ON integrations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_bug_reports_updated_at BEFORE UPDATE ON bug_reports FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_feature_requests_updated_at BEFORE UPDATE ON feature_requests FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_changelog_entries_updated_at BEFORE UPDATE ON changelog_entries FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default modules
INSERT INTO modules (slug, name, description, latest_version, base_price_cents, per_user_price_cents) VALUES
('messaging', 'Team Messaging', 'Real-time team communication and collaboration', '1.0.0', 0, 0),
('health-safety', 'Health & Safety', 'Hazard management, incident reporting, and safety compliance', '1.0.0', 5000, 500),
('tasks', 'Task Management', 'Project and task tracking with team collaboration', '1.0.0', 3000, 300);

-- Insert default permissions for core system
INSERT INTO permissions (module_slug, role, action, resource) VALUES
-- Super admin permissions
('core', 'super_admin', '*', '*'),
-- Company admin permissions
('core', 'admin', 'read', 'company'),
('core', 'admin', 'update', 'company'),
('core', 'admin', 'read', 'members'),
('core', 'admin', 'create', 'members'),
('core', 'admin', 'update', 'members'),
('core', 'admin', 'delete', 'members'),
('core', 'admin', 'read', 'billing'),
('core', 'admin', 'update', 'billing'),
('core', 'admin', 'read', 'modules'),
('core', 'admin', 'update', 'modules'),
-- Regular user permissions
('core', 'user', 'read', 'company'),
('core', 'user', 'read', 'members'),
('core', 'user', 'read', 'profile'),
('core', 'user', 'update', 'profile');
