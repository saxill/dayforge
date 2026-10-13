package com.omnirush.dayforge.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.omnirush.dayforge.data.DayforgeViewModel
import com.omnirush.dayforge.model.Article
import com.omnirush.dayforge.model.Manga
import com.omnirush.dayforge.model.SampleData

private enum class DiscoverSection { BRIEF, MANGA }

@Composable
fun DiscoverScreen(viewModel: DayforgeViewModel, padding: PaddingValues) {
    var section by remember { mutableStateOf(DiscoverSection.BRIEF) }
    var selectedArticle by remember { mutableStateOf<Article?>(null) }
    var selectedManga by remember { mutableStateOf<Manga?>(null) }
    Column(
        Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Spacer(Modifier.size(6.dp))
        Text("DISCOVER", style = MaterialTheme.typography.labelLarge, color = InkSoft, fontWeight = FontWeight.Bold)
        Text("Read something good", style = MaterialTheme.typography.headlineMedium)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(selected = section == DiscoverSection.BRIEF, onClick = { section = DiscoverSection.BRIEF }, label = { Text("AI Brief") })
            FilterChip(selected = section == DiscoverSection.MANGA, onClick = { section = DiscoverSection.MANGA }, label = { Text("Manga Shelf") })
        }

        if (section == DiscoverSection.BRIEF) {
            SampleData.articles.forEach { article ->
                DayCard(Modifier.clickable { selectedArticle = article }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        AccentIcon("✦", Blue)
                        Spacer(Modifier.size(12.dp))
                        Column(Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                TinyTag(article.tag, Blue)
                                Spacer(Modifier.size(8.dp))
                                Text("${article.minutes} min", style = MaterialTheme.typography.labelMedium, color = InkSoft)
                            }
                            Spacer(Modifier.size(7.dp))
                            Text(article.title, style = MaterialTheme.typography.titleMedium)
                            Text(article.summary, color = InkSoft)
                        }
                    }
                }
            }
        } else {
            viewModel.data.manga.forEach { manga ->
                DayCard(Modifier.clickable { selectedManga = manga }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        AccentIcon(manga.title.first().toString(), Moss)
                        Spacer(Modifier.size(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(manga.title, style = MaterialTheme.typography.titleMedium)
                            Text("${manga.author} · ${manga.genre}", color = InkSoft)
                            Spacer(Modifier.size(6.dp))
                            ProgressBar(if (manga.chapters == 0) 0f else manga.progress.toFloat() / manga.chapters, Moss)
                            Spacer(Modifier.size(4.dp))
                            Text("${manga.progress}/${manga.chapters} chapters · ${manga.libraryStatus ?: "Not saved"}", style = MaterialTheme.typography.labelSmall, color = InkSoft)
                        }
                    }
                }
            }
        }
        Spacer(Modifier.size(18.dp))
    }

    selectedArticle?.let { article -> ArticleDetailDialog(article, onDismiss = { selectedArticle = null }) }
    selectedManga?.let { manga -> MangaDetailDialog(viewModel, manga, onDismiss = { selectedManga = null }) }
}

@Composable
private fun ArticleDetailDialog(article: Article, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(article.title) },
        text = { Column(verticalArrangement = Arrangement.spacedBy(12.dp)) { TinyTag("${article.tag} · ${article.minutes} min", Blue); Text(article.body) } },
        confirmButton = { Button(onClick = onDismiss) { Text("Done") } },
    )
}

@Composable
private fun MangaDetailDialog(viewModel: DayforgeViewModel, manga: Manga, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(manga.title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                TinyTag("${manga.genre} · ${manga.status}", Moss)
                Text(manga.blurb)
                Text("Progress: ${manga.progress}/${manga.chapters} chapters", color = InkSoft)
            }
        },
        confirmButton = {
            Button(onClick = {
                val updated = viewModel.data.manga.map { if (it.id == manga.id) it.copy(progress = (it.progress + 1).coerceAtMost(it.chapters), libraryStatus = it.libraryStatus ?: "reading") else it }
                viewModel.updateManga(updated)
                onDismiss()
            }) { Text("Mark next chapter") }
        },
        dismissButton = { OutlinedButton(onClick = onDismiss) { Text("Close") } },
    )
}
