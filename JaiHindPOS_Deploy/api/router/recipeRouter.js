const express = require('express');
const router = express.Router();

const recipeController = require('../controller/recipeController');
const authenticate = require('../middleware/authMiddleware');

router.get('/recipes', authenticate, recipeController.getRecipes);
router.get('/recipes/:recipeId', authenticate, recipeController.getRecipe);
router.post('/recipes', authenticate, recipeController.createRecipe);
router.put('/recipes/:recipeId', authenticate, recipeController.updateRecipe);
router.patch('/recipes/:recipeId/status', authenticate, recipeController.updateRecipeStatus);

module.exports = router;
