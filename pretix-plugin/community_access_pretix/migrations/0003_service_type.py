from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [('community_access_pretix', '0002_alter_cartbinding_id_serviceevent_serviceorder_and_more')]
    operations = [
        migrations.CreateModel(name='ServiceType', fields=[
            ('id', models.UUIDField(primary_key=True, serialize=False)),
            ('version', models.PositiveIntegerField()),
            ('catalog', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, to='community_access_pretix.serviceevent')),
            ('item', models.OneToOneField(on_delete=django.db.models.deletion.PROTECT, to='pretixbase.item')),
            ('quota', models.OneToOneField(on_delete=django.db.models.deletion.PROTECT, to='pretixbase.quota')),
        ]),
        migrations.AddField(model_name='serviceorder', name='service_type', field=models.ForeignKey(null=True, on_delete=django.db.models.deletion.PROTECT, to='community_access_pretix.servicetype')),
    ]
