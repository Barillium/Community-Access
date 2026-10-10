from django.db import models


class CartBinding(models.Model):
    event = models.ForeignKey('pretixbase.Event', on_delete=models.CASCADE)
    cart_id = models.CharField(max_length=255)
    order_id = models.UUIDField(unique=True)
    browser_nonce = models.CharField(max_length=64)
    grant = models.JSONField()

    class Meta:
        unique_together = (('event', 'cart_id'),)


class ServiceEvent(models.Model):
    id = models.UUIDField(primary_key=True)
    event = models.OneToOneField('pretixbase.Event', on_delete=models.PROTECT)
    item = models.OneToOneField('pretixbase.Item', on_delete=models.PROTECT)
    quota = models.OneToOneField('pretixbase.Quota', on_delete=models.PROTECT)
    version = models.PositiveIntegerField()


class ServiceOrder(models.Model):
    id = models.UUIDField(primary_key=True)
    catalog = models.ForeignKey(ServiceEvent, on_delete=models.PROTECT)
    order = models.OneToOneField('pretixbase.Order', null=True, on_delete=models.PROTECT)
    service_type = models.ForeignKey('ServiceType', null=True, on_delete=models.PROTECT)
    subject = models.CharField(max_length=64)
    account_id = models.CharField(max_length=64)
    cart_id = models.CharField(max_length=255, unique=True)
    state = models.CharField(max_length=16, default='pending')
    blocked = models.BooleanField(default=False)
    valid_payment = models.BooleanField(default=False)
    total_cents = models.PositiveIntegerField()
    fee_cents = models.PositiveIntegerField()
    fee_basis_points = models.PositiveIntegerField()
    refunded_cents = models.PositiveIntegerField(default=0)
    fee_refunded_cents = models.PositiveIntegerField(default=0)
    expires_at = models.DateTimeField()

    class Meta:
        constraints = [models.UniqueConstraint(fields=['catalog', 'subject'], condition=models.Q(state__in=['pending', 'paid']), name='ca_native_one_person')]


class ServiceRefund(models.Model):
    id = models.UUIDField(primary_key=True)
    order = models.ForeignKey(ServiceOrder, on_delete=models.PROTECT)
    refund = models.OneToOneField('pretixbase.OrderRefund', null=True, on_delete=models.PROTECT)
    amount_cents = models.PositiveIntegerField()
    fee_cents = models.PositiveIntegerField()


class ServiceType(models.Model):
    id = models.UUIDField(primary_key=True)
    catalog = models.ForeignKey(ServiceEvent, on_delete=models.PROTECT)
    item = models.OneToOneField('pretixbase.Item', on_delete=models.PROTECT)
    quota = models.OneToOneField('pretixbase.Quota', on_delete=models.PROTECT)
    version = models.PositiveIntegerField()
