#
# Cookbook Name:: postgresql
# Recipe:: default
#
# Copyright 2012, OpenStreetMap Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if File.exists?("/etc/init.d/postgresql")
  service "postgresql" do
    action [ :enable, :start ]
    supports :status => true, :restart => true, :reload => true
  end
end

node[:postgresql][:versions].each do |version|
  package "postgresql-#{version}"
  package "postgresql-client-#{version}"
  package "postgresql-contrib-#{version}"
  package "postgresql-server-dev-#{version}"

  if File.exists?("/etc/init.d/postgresql-#{version}")
    service "postgresql-#{version}" do
      action [ :enable, :start ]
      supports :status => true, :restart => true, :reload => true
    end
  end

  defaults = node[:postgresql][:settings][:defaults] || {}
  settings = node[:postgresql][:settings][version] || {}

  template "/etc/postgresql/#{version}/main/postgresql.conf" do
    source "postgresql.conf.erb"
    owner "postgres"
    group "postgres"
    mode 0644
    variables :version => version, :defaults => defaults, :settings => settings
    if File.exists?("/etc/init.d/postgresql-#{version}")
      notifies :reload, resources(:service => "postgresql-#{version}")
    else
      notifies :reload, resources(:service => "postgresql")
    end
  end

  template "/etc/postgresql/#{version}/main/pg_hba.conf" do
    source "pg_hba.conf.erb"
    owner "postgres"
    group "postgres"
    mode 0640
    variables :early_rules => settings[:early_authentication_rules] || defaults[:early_authentication_rules],
              :late_rules => settings[:late_authentication_rules] || defaults[:late_authentication_rules]
    if File.exists?("/etc/init.d/postgresql-#{version}")
      notifies :reload, resources(:service => "postgresql-#{version}")
    else
      notifies :reload, resources(:service => "postgresql")
    end
  end

  template "/etc/postgresql/#{version}/main/pg_ident.conf" do
    source "pg_ident.conf.erb"
    owner "postgres"
    group "postgres"
    mode 0640
    variables :maps => settings[:user_name_maps] || defaults[:user_name_maps]
    if File.exists?("/etc/init.d/postgresql-#{version}")
      notifies :reload, resources(:service => "postgresql-#{version}")
    else
      notifies :reload, resources(:service => "postgresql")
    end
  end

  link "/var/lib/postgresql/#{version}/main/server.crt" do
    to "/etc/ssl/certs/ssl-cert-snakeoil.pem"
  end

  link "/var/lib/postgresql/#{version}/main/server.key" do
    to "/etc/ssl/private/ssl-cert-snakeoil.key"
  end

  restore_command = settings[:restore_command] || defaults[:restore_command]
  standby_mode = settings[:standby_mode] || defaults[:standby_mode]

  if restore_command || standby_mode == "on"
    template "/var/lib/postgresql/#{version}/main/recovery.conf" do
      source "recovery.conf.erb"
      owner "postgres"
      group "postgres"
      mode 0640
      variables :defaults => defaults, :settings => settings
      if File.exists?("/etc/init.d/postgresql-#{version}")
        notifies :reload, resources(:service => "postgresql-#{version}")
      else
        notifies :reload, resources(:service => "postgresql")
      end
    end
  else
    template "/var/lib/postgresql/#{version}/main/recovery.conf" do
      action :delete
      if File.exists?("/etc/init.d/postgresql-#{version}")
        notifies :reload, resources(:service => "postgresql-#{version}")
      else
        notifies :reload, resources(:service => "postgresql")
      end
    end
  end
end

ohai_plugin "postgresql" do
  template "ohai.rb.erb"
end

package "ptop"
package "libdbd-pg-perl"

clusters = node[:postgresql][:clusters] || []

clusters.each do |name,details|
  suffix = name.tr("/", ":")

  munin_plugin "postgres_bgwriter_#{suffix}" do
    target "postgres_bgwriter"
    conf "munin.erb"
    conf_variables :port => details[:port]
  end

  munin_plugin "postgres_checkpoints_#{suffix}" do
    target "postgres_checkpoints"
    conf "munin.erb"
    conf_variables :port => details[:port]
  end

  munin_plugin "postgres_connections_db_#{suffix}" do
    target "postgres_connections_db"
    conf "munin.erb"
    conf_variables :port => details[:port]
  end

  munin_plugin "postgres_users_#{suffix}" do
    target "postgres_users"
    conf "munin.erb"
    conf_variables :port => details[:port]
  end

  munin_plugin "postgres_xlog_#{suffix}" do
    target "postgres_xlog"
    conf "munin.erb"
    conf_variables :port => details[:port]
  end

  if File.exist?("/var/lib/postgresql/#{details[:version]}/main/recovery.conf")
    munin_plugin "postgres_replication_#{suffix}" do
      target "postgres_replication"
      conf "munin.erb"
      conf_variables :port => details[:port]
    end
  end
end
