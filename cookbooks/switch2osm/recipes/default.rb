#
# Cookbook Name:: switch2osm
# Recipe:: default
#
# Copyright 2013, OpenStreetMap Foundation
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

include_recipe "wordpress"

passwords = data_bag_item("switch2osm", "passwords")

wordpress_site "switch2osm.org" do
  aliases "www.switch2osm.org", "switch2osm.com", "www.switch2osm.com"
  directory "/srv/switch2osm.org"
  database_name "switch2osm-blog"
  database_user "switch2osm-user"
  database_password passwords["switch2osm-user"]
end

wordpress_theme "picolight" do
  site "switch2osm.org"
  repository "git://github.com/Firefishy/picolight-s2o.git"
  revision "master"
end
