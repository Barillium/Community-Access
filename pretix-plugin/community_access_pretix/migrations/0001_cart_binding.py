from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True
    dependencies = [('pretixbase', '0001_initial')]
    operations = [migrations.CreateModel(name='CartBinding', fields=[
        ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
        ('cart_id', models.CharField(max_length=255)),
        ('order_id', models.UUIDField(unique=True)),
        ('browser_nonce', models.CharField(max_length=64)),
        ('grant', models.JSONField()),
        ('event', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='pretixbase.event')),
    ], options={'unique_together': {('event', 'cart_id')}})]
