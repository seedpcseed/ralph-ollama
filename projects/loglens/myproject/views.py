from django.shortcuts import render

def home(request):
    return render(request, 'home.html')  # Create this template in 'templates' folder