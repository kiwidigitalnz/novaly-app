-- Enable Row Level Security on all tables
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE bug_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE changelog_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user's company IDs
CREATE OR REPLACE FUNCTION get_user_company_ids()
RETURNS UUID[] AS $$
BEGIN
  RETURN ARRAY(
    SELECT company_id 
    FROM company_members 
    WHERE user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user is super admin
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS(
    SELECT 1 
    FROM company_members 
    WHERE user_id = auth.uid() 
    AND role = 'super_admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user is admin of a company
CREATE OR REPLACE FUNCTION is_company_admin(company_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS(
    SELECT 1 
    FROM company_members 
    WHERE user_id = auth.uid() 
    AND company_id = company_uuid 
    AND role IN ('admin', 'super_admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user is member of a company
CREATE OR REPLACE FUNCTION is_company_member(company_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS(
    SELECT 1 
    FROM company_members 
    WHERE user_id = auth.uid() 
    AND company_id = company_uuid
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Companies policies
CREATE POLICY "Users can view their companies" ON companies
  FOR SELECT USING (
    is_super_admin() OR 
    id = ANY(get_user_company_ids())
  );

CREATE POLICY "Super admins can insert companies" ON companies
  FOR INSERT WITH CHECK (is_super_admin());

CREATE POLICY "Company admins can update their company" ON companies
  FOR UPDATE USING (
    is_super_admin() OR 
    is_company_admin(id)
  );

CREATE POLICY "Super admins can delete companies" ON companies
  FOR DELETE USING (is_super_admin());

-- User profiles policies
CREATE POLICY "Users can view all profiles" ON user_profiles
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can insert their own profile" ON user_profiles
  FOR INSERT WITH CHECK (id = auth.uid());

CREATE POLICY "Users can update their own profile" ON user_profiles
  FOR UPDATE USING (id = auth.uid());

CREATE POLICY "Super admins can update any profile" ON user_profiles
  FOR UPDATE USING (is_super_admin());

-- Company members policies
CREATE POLICY "Users can view members of their companies" ON company_members
  FOR SELECT USING (
    is_super_admin() OR
    company_id = ANY(get_user_company_ids())
  );

CREATE POLICY "Company admins can insert members" ON company_members
  FOR INSERT WITH CHECK (
    is_super_admin() OR
    is_company_admin(company_id)
  );

CREATE POLICY "Company admins can update members" ON company_members
  FOR UPDATE USING (
    is_super_admin() OR
    is_company_admin(company_id)
  );

CREATE POLICY "Company admins can delete members" ON company_members
  FOR DELETE USING (
    is_super_admin() OR
    is_company_admin(company_id)
  );

-- Invitations policies
CREATE POLICY "Company members can view invitations" ON invitations
  FOR SELECT USING (
    is_super_admin() OR
    is_company_member(company_id)
  );

CREATE POLICY "Company admins can create invitations" ON invitations
  FOR INSERT WITH CHECK (
    is_super_admin() OR
    is_company_admin(company_id)
  );

CREATE POLICY "Company admins can update invitations" ON invitations
  FOR UPDATE USING (
    is_super_admin() OR
    is_company_admin(company_id)
  );

CREATE POLICY "Company admins can delete invitations" ON invitations
  FOR DELETE USING (
    is_super_admin() OR
    is_company_admin(company_id)
  );

-- Modules policies (public read, super admin write)
CREATE POLICY "Anyone can view active modules" ON modules
  FOR SELECT USING (is_active = true OR is_super_admin());

CREATE POLICY "Super admins can manage modules" ON modules
  FOR ALL USING (is_super_admin());

-- Company modules policies
CREATE POLICY "Company members can view their modules" ON company_modules
  FOR SELECT USING (
    is_super_admin() OR
    is_company_member(company_id)
  );

CREATE POLICY "Company admins can manage modules" ON company_modules
  FOR ALL USING (
    is_super_admin() OR
    is_company_admin(company_id)
  );

-- Subscriptions policies
CREATE POLICY "Company admins can view subscriptions" ON subscriptions
  FOR SELECT USING (
    is_super_admin() OR
    is_company_admin(company_id)
  );

CREATE POLICY "Super admins can manage subscriptions" ON subscriptions
  FOR ALL USING (is_super_admin());

-- Permissions policies (public read)
CREATE POLICY "Anyone can view permissions" ON permissions
  FOR SELECT USING (true);

CREATE POLICY "Super admins can manage permissions" ON permissions
  FOR ALL USING (is_super_admin());

-- Notifications policies
CREATE POLICY "Users can view their notifications" ON notifications
  FOR SELECT USING (
    user_id = auth.uid() OR
    is_super_admin()
  );

CREATE POLICY "Users can update their notifications" ON notifications
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "System can insert notifications" ON notifications
  FOR INSERT WITH CHECK (true); -- Will be restricted by Edge Functions

-- Activity log policies
CREATE POLICY "Company members can view activity" ON activity_log
  FOR SELECT USING (
    is_super_admin() OR
    is_company_member(company_id)
  );

CREATE POLICY "System can insert activity" ON activity_log
  FOR INSERT WITH CHECK (true); -- Will be restricted by Edge Functions

-- Conversations policies
CREATE POLICY "Company members can view conversations" ON conversations
  FOR SELECT USING (
    is_super_admin() OR
    is_company_member(company_id)
  );

CREATE POLICY "Company members can create conversations" ON conversations
  FOR INSERT WITH CHECK (
    is_super_admin() OR
    is_company_member(company_id)
  );

CREATE POLICY "Conversation creators can update" ON conversations
  FOR UPDATE USING (
    is_super_admin() OR
    created_by = auth.uid()
  );

-- Conversation members policies
CREATE POLICY "Users can view their conversation memberships" ON conversation_members
  FOR SELECT USING (
    user_id = auth.uid() OR
    is_super_admin() OR
    EXISTS(
      SELECT 1 FROM conversations c 
      WHERE c.id = conversation_id 
      AND is_company_member(c.company_id)
    )
  );

CREATE POLICY "Users can manage their conversation memberships" ON conversation_members
  FOR ALL USING (
    user_id = auth.uid() OR
    is_super_admin()
  );

-- Messages policies
CREATE POLICY "Conversation members can view messages" ON messages
  FOR SELECT USING (
    is_super_admin() OR
    EXISTS(
      SELECT 1 FROM conversation_members cm
      WHERE cm.conversation_id = messages.conversation_id
      AND cm.user_id = auth.uid()
    )
  );

CREATE POLICY "Conversation members can send messages" ON messages
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    EXISTS(
      SELECT 1 FROM conversation_members cm
      WHERE cm.conversation_id = messages.conversation_id
      AND cm.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own messages" ON messages
  FOR UPDATE USING (user_id = auth.uid());

-- Integrations policies
CREATE POLICY "Company members can view integrations" ON integrations
  FOR SELECT USING (
    is_super_admin() OR
    is_company_member(company_id)
  );

CREATE POLICY "Company admins can manage integrations" ON integrations
  FOR ALL USING (
    is_super_admin() OR
    is_company_admin(company_id)
  );

-- Bug reports policies
CREATE POLICY "Company members can view bug reports" ON bug_reports
  FOR SELECT USING (
    is_super_admin() OR
    is_company_member(company_id)
  );

CREATE POLICY "Company members can create bug reports" ON bug_reports
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (is_super_admin() OR is_company_member(company_id))
  );

CREATE POLICY "Users can update their bug reports" ON bug_reports
  FOR UPDATE USING (
    user_id = auth.uid() OR
    is_super_admin() OR
    is_company_admin(company_id)
  );

-- Feature requests policies
CREATE POLICY "Company members can view feature requests" ON feature_requests
  FOR SELECT USING (
    is_super_admin() OR
    is_company_member(company_id)
  );

CREATE POLICY "Company members can create feature requests" ON feature_requests
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (is_super_admin() OR is_company_member(company_id))
  );

CREATE POLICY "Users can update their feature requests" ON feature_requests
  FOR UPDATE USING (
    user_id = auth.uid() OR
    is_super_admin()
  );

-- Changelog entries policies (public read)
CREATE POLICY "Anyone can view published changelog" ON changelog_entries
  FOR SELECT USING (is_published = true OR is_super_admin());

CREATE POLICY "Super admins can manage changelog" ON changelog_entries
  FOR ALL USING (is_super_admin());

-- Events policies
CREATE POLICY "Company members can view events" ON events
  FOR SELECT USING (
    is_super_admin() OR
    (company_id IS NULL) OR
    is_company_member(company_id)
  );

CREATE POLICY "System can insert events" ON events
  FOR INSERT WITH CHECK (true); -- Will be restricted by Edge Functions

-- Create function to handle user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  company_uuid UUID;
  company_name TEXT;
  company_slug TEXT;
BEGIN
  -- Create user profile
  INSERT INTO user_profiles (id, email, name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)));

  -- If this is the first user, make them super admin
  IF NOT EXISTS (SELECT 1 FROM company_members WHERE role = 'super_admin') THEN
    -- Create a default company for the super admin
    company_name := COALESCE(NEW.raw_user_meta_data->>'company_name', 'My Company');
    company_slug := lower(regexp_replace(company_name, '[^a-zA-Z0-9]+', '-', 'g'));
    
    -- Ensure unique slug
    WHILE EXISTS (SELECT 1 FROM companies WHERE slug = company_slug) LOOP
      company_slug := company_slug || '-' || floor(random() * 1000)::text;
    END LOOP;
    
    INSERT INTO companies (name, slug, status)
    VALUES (company_name, company_slug, 'active')
    RETURNING id INTO company_uuid;
    
    -- Make user super admin of this company
    INSERT INTO company_members (user_id, company_id, role)
    VALUES (NEW.id, company_uuid, 'super_admin');
    
    -- Update user's default company
    UPDATE user_profiles 
    SET default_company_id = company_uuid 
    WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Create function to log activity
CREATE OR REPLACE FUNCTION log_activity(
  p_company_id UUID,
  p_action TEXT,
  p_resource_type TEXT,
  p_resource_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO activity_log (company_id, user_id, action, resource_type, resource_id, metadata)
  VALUES (p_company_id, auth.uid(), p_action, p_resource_type, p_resource_id, p_metadata);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to emit notification
CREATE OR REPLACE FUNCTION emit_notification(
  p_user_ids UUID[],
  p_company_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_message TEXT DEFAULT NULL,
  p_payload JSONB DEFAULT '{}'
)
RETURNS VOID AS $$
DECLARE
  user_id UUID;
BEGIN
  FOREACH user_id IN ARRAY p_user_ids
  LOOP
    INSERT INTO notifications (user_id, company_id, type, title, message, payload)
    VALUES (user_id, p_company_id, p_type, p_title, p_message, p_payload);
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create materialized view for platform metrics (for super admin dashboard)
CREATE MATERIALIZED VIEW vw_platform_metrics AS
SELECT
  (SELECT COUNT(*) FROM companies WHERE status = 'active') as active_companies,
  (SELECT COUNT(*) FROM companies WHERE status = 'trial') as trial_companies,
  (SELECT COUNT(*) FROM companies WHERE status = 'delinquent') as delinquent_companies,
  (SELECT COUNT(*) FROM companies WHERE status = 'suspended') as suspended_companies,
  (SELECT COUNT(*) FROM user_profiles) as total_users,
  (SELECT COUNT(*) FROM company_members WHERE role = 'admin') as admin_users,
  (SELECT COUNT(*) FROM subscriptions WHERE status = 'active') as active_subscriptions,
  (SELECT COUNT(*) FROM bug_reports WHERE status = 'open') as open_bugs,
  (SELECT COUNT(*) FROM feature_requests WHERE status IN ('submitted', 'planned')) as pending_features,
  NOW() as last_updated;

-- Create index on materialized view
CREATE UNIQUE INDEX idx_vw_platform_metrics_singleton ON vw_platform_metrics ((1));

-- Create function to refresh platform metrics
CREATE OR REPLACE FUNCTION refresh_platform_metrics()
RETURNS VOID AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY vw_platform_metrics;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

-- Grant access to materialized view
GRANT SELECT ON vw_platform_metrics TO authenticated;
