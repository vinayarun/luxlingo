package com.luxlingo.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.compose.ui.platform.LocalContext
import com.luxlingo.app.data.UserPreferencesRepository
import com.luxlingo.app.ui.LessonViewModel
import com.luxlingo.app.ui.LessonViewModelFactory
import com.luxlingo.app.ui.MainViewModel
import com.luxlingo.app.ui.screens.HomeScreen
import com.luxlingo.app.ui.screens.LessonScreen
import com.luxlingo.app.ui.screens.ResultScreen
import com.luxlingo.app.ui.theme.LuxLingoTheme
import com.luxlingo.app.ui.navigation.AppNavHost
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            LuxLingoTheme {
                val navController = rememberNavController()
                val mainViewModel: MainViewModel = hiltViewModel()
                val userPreferencesRepository = UserPreferencesRepository(LocalContext.current)
                val xp by userPreferencesRepository.xp.collectAsState(initial = 0)
                val streak by userPreferencesRepository.streak.collectAsState(initial = 0)

                // Observe the reactive 'units' flow
                // val units by mainViewModel.units.collectAsState()
                
                
                
                AppNavHost(
                    navController = navController,
                    xp = xp,
                    streak = streak
                )
            }
        }
    }
}
