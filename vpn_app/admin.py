from django.contrib import admin
from .models import AggregateSubscription, SourceLink

class SourceLinkInline(admin.TabularInline):
    model = SourceLink
    extra = 1

@admin.register(AggregateSubscription)
class AggregateSubscriptionAdmin(admin.ModelAdmin):
    list_display = ('name', 'token', 'created_at')
    inlines = [SourceLinkInline]
    readonly_fields = ('token',)
