from django.urls import path
from . import views

urlpatterns = [
    path('', views.index, name='index'),
    path('dashboard/', views.dashboard, name='dashboard'),
    path('sub/create/', views.create_subscription, name='create_subscription'),
    path('sub/<int:pk>/edit/', views.edit_subscription, name='edit_subscription'),
    path('sub/<int:pk>/delete/', views.delete_subscription, name='delete_subscription'),
    path('sub/<int:sub_pk>/add-link/', views.add_link, name='add_link'),
    path('link/<int:link_pk>/delete/', views.delete_link, name='delete_link'),
    path('link/<int:link_pk>/toggle/', views.toggle_link, name='toggle_link'),
    path('link/<int:link_pk>/check/', views.check_link, name='check_link'),
    path('sub/<str:token>/', views.aggregate_sub_view, name='aggregate_sub'),

]
