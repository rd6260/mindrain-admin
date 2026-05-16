
p = '/home/senku/dev/yajurveda/mindrain_admin/lib/pages/email_management.dart'
with open(p) as f: c = f.read()

# Fix escaped dollar signs written by Python script
c = c.replace(r'\${', '${').replace(r'\$', '$')

with open(p, 'w') as f: f.write(c)
print('Fixed dollar signs in email_management.dart')
