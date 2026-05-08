package com.luxlingo.app.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import com.luxlingo.app.ui.screens.HomeScreen
import com.luxlingo.app.ui.screens.ExerciseScreen
import com.luxlingo.app.ui.MainViewModel
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue

@Composable
fun AppNavHost(
    navController: NavHostController,
    xp: Int,    // Currently unused, but keeps MainActivity happy
    streak: Int // Currently unused, but keeps MainActivity happy
) {
    NavHost(navController = navController, startDestination = "curriculum") {
        composable("curriculum") {
            val viewModel: MainViewModel = hiltViewModel()
            val units by viewModel.units.collectAsState()
            
            HomeScreen(
                units = units,
                xp = xp,
                streak = streak,
                onLessonSelected = { unitId, lessonId ->
                    navController.navigate("exercise/$lessonId")
                }
            )
        }
        composable(
            // Changed "lesson" to "exercise" to match CurriculumScreen's navigate call
            route = "exercise/{lessonId}", 
            arguments = listOf(navArgument("lessonId") { type = NavType.StringType })
        ) {
            ExerciseScreen(navController = navController)
        }
    }
}