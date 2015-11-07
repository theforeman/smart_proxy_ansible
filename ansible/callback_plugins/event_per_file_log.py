
# (C) 2012, Michael DeHaan, <michael.dehaan@gmail.com>

# This file is part of Ansible
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.

import os
from datetime import datetime
import time
import json
import uuid

TIME_FORMAT="%Y-%m-%d_%H%M%S_%f"
FILE_NAME_FORMAT="%(now)s-%(host)s.json"
MSG_FORMAT='{"host":"%(host)s","timestamp":"%(now)s", "category":"%(category)s", "data": %(data)s}' + "\n"

if os.environ.has_key('ANSIBLE_EVENTS_DIR'):
    DATA_DIR=os.environ.get('ANSIBLE_EVENTS_DIR')
else:
    DATA_DIR="/tmp/ansible/events/" + uuid.uuid4().hex

if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR)

class CallbackModule(object):

    """
    logs playbook results, per host, in LOG_DIR
    """

    def log(self, host, category, data):
        if type(data) != dict:
            data = dict(msg=data)
        data = json.dumps(data)
        timestamp = time.time()
        now = datetime.fromtimestamp(timestamp).strftime(TIME_FORMAT)
        path = os.path.join(DATA_DIR, FILE_NAME_FORMAT % dict(now=now, host=host))
        fd = open(path, "w")
        fd.write(MSG_FORMAT % dict(host=host, now=timestamp, category=category, data=data))
        fd.close()


    def on_any(self, *args, **kwargs):
        pass

    def runner_on_failed(self, host, res, ignore_errors=False):
        self.log(host, 'FAILED', res)

    def runner_on_ok(self, host, res):
        self.log(host, 'OK', res)

    def runner_on_skipped(self, host, item=None):
        self.log(host, 'SKIPPED', '...')

    def runner_on_unreachable(self, host, res):
        self.log(host, 'UNREACHABLE', res)

    def runner_on_no_hosts(self):
        pass

    def runner_on_async_poll(self, host, res, jid, clock):
        pass

    def runner_on_async_ok(self, host, res, jid):
        pass

    def runner_on_async_failed(self, host, res, jid):
        self.log(host, 'ASYNC_FAILED', res)

    def playbook_on_start(self):
        pass

    def playbook_on_notify(self, host, handler):
        pass

    def playbook_on_no_hosts_matched(self):
        pass

    def playbook_on_no_hosts_remaining(self):
        pass

    def playbook_on_task_start(self, name, is_conditional):
        pass

    def playbook_on_vars_prompt(self, varname, private=True, prompt=None, encrypt=None, confirm=False, salt_size=None, salt=None, default=None):
        pass

    def playbook_on_setup(self):
        pass

    def playbook_on_import_for_host(self, host, imported_file):
        self.log(host, 'IMPORTED', imported_file)

    def playbook_on_not_import_for_host(self, host, missing_file):
        self.log(host, 'NOTIMPORTED', missing_file)

    def playbook_on_play_start(self, name):
        pass

    def playbook_on_stats(self, stats):
        pass
