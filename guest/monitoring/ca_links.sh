#!/bin/bash
# Which database targets have a corrective action attached to a threshold (oracle on oem24).
# mgmt$ca_targets alone is not proof: it also lists a CA copy that no threshold uses.
source ~/.bash_profile
sqlplus -s "sysman/${LAB_PWD}@oem24.localdomain:1521/empdb.localdomain" <<'SQL'
set lines 200 pages 0 feedback off trimspool on
select 'LINK|'||t.target_name||'|'||c.coll_name||'|warn='||nvl(a.ca_name,rawtohex(c.warn_action_job_id))
from mgmt_policy_assoc_cfg c join mgmt_targets t on t.target_guid = c.object_guid
left join mgmt_corrective_action a on a.job_id = c.warn_action_job_id
where t.target_name in ('orcl_prm1','orcl_stb1') and c.warn_action_job_id is not null
order by 1;
SQL
