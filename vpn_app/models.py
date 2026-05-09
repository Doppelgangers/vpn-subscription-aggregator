import uuid
from django.db import models

class AggregateSubscription(models.Model):
    name = models.CharField("Название (внутреннее)", max_length=100, default="My Multi-Node Sub")
    client_title = models.CharField("Название (для клиента)", max_length=100, blank=True, help_text="То, что увидит пользователь в приложении")
    token = models.CharField("Токен подписки", max_length=64, default=uuid.uuid4, unique=True)
    custom_base_url = models.CharField("Кастомный домен/URL", max_length=255, blank=True, help_text="Напр.: subses.doppelgangeres.com:5090")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

    @property
    def total_configs(self):
        return sum(link.config_count for link in self.links.filter(is_active=True))

    class Meta:
        verbose_name = "Сводная подписка"
        verbose_name_plural = "Сводные подписки"

class SourceLink(models.Model):
    subscription = models.ForeignKey(AggregateSubscription, on_delete=models.CASCADE, related_name="links")
    url = models.URLField("Ссылка на подписку (от 3x-ui)", max_length=500)
    remark = models.CharField("Примечание", max_length=255, blank=True, help_text="Напр.: Сервер Германия")
    is_active = models.BooleanField("Активна", default=True)
    
    # New fields for metadata
    last_status_code = models.IntegerField("Код ответа", null=True, blank=True)
    config_count = models.IntegerField("Кол-во конфигов", default=0)
    error_message = models.TextField("Ошибка", blank=True)
    last_checked = models.DateTimeField("Последняя проверка", null=True, blank=True)

    def __str__(self):
        return self.url
