#%% Import dependencies
import undetected_chromedriver as uc
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import os
import random
import time
from selenium.webdriver.common.keys import Keys
import pandas as pd
from datetime import datetime
from prefect import task, flow
from prefect.tasks import task_input_hash
from datetime import timedelta


@task(cache_key_fn=None)  # Disable caching for driver initialization
def initialize_driver():
    """Initialize and return the Chrome driver"""
    chrome_data_dir = os.path.expanduser("~/linkedin_chrome_data")
    if not os.path.exists(chrome_data_dir):
        os.makedirs(chrome_data_dir)
    
    options = Options()
    options.add_argument(f'--user-data-dir={chrome_data_dir}')
    
    driver = uc.Chrome(
        options=options,
        version_main=131,
        user_data_dir=chrome_data_dir,
        headless=True  # Also set it here for undetected_chromedriver
    )
    return driver, WebDriverWait(driver, 20)


@task(cache_key_fn=task_input_hash, cache_expiration=timedelta(hours=1))
def load_commented_posts():
    """Load previously commented posts from CSV"""
    csv_file = 'commented_posts.csv'
    if os.path.exists(csv_file):
        return pd.read_csv(csv_file)['author'].tolist()
    return []

@task(cache_key_fn=task_input_hash, cache_expiration=timedelta(hours=1))
def save_commented_post(author):
    """Save newly commented post to CSV"""
    csv_file = 'commented_posts.csv'
    new_row = pd.DataFrame({'author': [author], 'date_commented': [datetime.now()]})
    if os.path.exists(csv_file):
        df = pd.read_csv(csv_file)
        df = pd.concat([df, new_row], ignore_index=True)
    else:
        df = new_row
    df.to_csv(csv_file, index=False)


@task(cache_key_fn=None)  # Disable caching for tasks that use driver
def collect_posts(driver, wait):
    """Collect and return post details"""
    try:
        # Wait for posts to load
        posts = wait.until(EC.presence_of_all_elements_located((By.CLASS_NAME, "bdLLTH")))
        previously_commented = load_commented_posts()
        post_details = []
        
        for i, post in enumerate(posts):
            try:
                # Get author name and post title
                author = post.find_element(By.CLASS_NAME, "lka-duB").text
                title = post.find_element(By.CLASS_NAME, "SmgaB").text
                
                # Only add posts from authors we haven't commented on before
                if author not in previously_commented:
                    post_details.append({
                        'element': post,
                        'author': author,
                        'title': title
                    })
                    print(f"New post {i+1} by {author}: {title}")
                else:
                    print(f"Skipping previously commented post by {author}")
            except Exception as e:
                print(f"Post {i+1}: {post.text[:100]}...")  # Fallback to showing first 100 chars
        return post_details
    except Exception as e:
        print(f"Error retrieving posts: {e}")
        return []


@task(cache_key_fn=None)  # Disable caching for tasks that use driver
def comment_on_posts(driver, wait, post_details):
    """Comment on collected posts"""
    for i, post_to_click in enumerate(post_details):
        try:
            # Get first name only
            first_name = post_to_click['author'].split()[0]
            
            # Create list of welcome message variations
            welcome_messages = [
                f"Welcome {first_name}! 👋 Great to have you in the community",
                f"Hey {first_name}! Welcome to the AI automation crew",
                f"Welcome {first_name}! You'll find some great automation ideas here",
                f"Hey {first_name}, welcome aboard! 👋",
                f"Welcome to the community {first_name}!",
                f"Hey {first_name}! Nice to have you here",
                f"Welcome {first_name}! Looking forward to your automation journey",
                f"Hey {first_name}! Welcome to the community 👋",
                f"Welcome aboard {first_name}! Glad you joined us",
                f"Hey {first_name}! You're going to like it here"
            ]
            
            # Randomly select a message
            text_to_enter = random.choice(welcome_messages)
            
            # Click the post
            post_to_click['element'].click()
            
            try:
                # Wait for input field to be present and visible
                comment_field = wait.until(EC.presence_of_element_located((By.CLASS_NAME, "tiptap")))
                wait.until(EC.element_to_be_clickable((By.CLASS_NAME, "tiptap")))
                
                # Additional wait after element is found
                time.sleep(2)
            
                # Click and enter text
                comment_field.click()
                driver.execute_script(f'arguments[0].innerHTML = "{text_to_enter}"', comment_field)
                
                # Wait a second before clicking comment button
                time.sleep(1)
            
            
            # Find and click the comment button
                comment_button = driver.find_element(By.CLASS_NAME, "iSJjQ")
                comment_button.click()
            except:
                print("Comment button not found")
            
            # After successful comment, save to CSV
            save_commented_post(post_to_click['author'])
            
            print(f"Comment posted successfully on post {i+1}: {text_to_enter}")
            
            # Wait 2 seconds before clicking the close button
            time.sleep(2)
            
            # Find and click the close button (try multiple approaches)
            try:
                close_button = driver.find_element(By.CSS_SELECTOR, "button.styled__ButtonWrapper-sc-dscagy-1.styled__CloseButton-sc-z30hfz-3")
                close_button.click()
            except:
                try:
                    close_button = driver.find_element(By.CLASS_NAME, "styled__CloseButton-sc-z30hfz-3")
                    close_button.click()
                except:
                    close_button = driver.find_element(By.XPATH, "//button[contains(@class, 'styled__CloseButton-sc-z30hfz-3')]")
                    close_button.click()
            
            # Wait a bit before processing next post
            time.sleep(5)
        
        except Exception as e:
            print(f"Error commenting on post {i+1}: {str(e)}")
            continue


@task(cache_key_fn=None)
def git_operations():
    """Push changes to Git repository after flow completion"""
    try:
        from git import Repo
        
        repo = Repo('.')
        git = repo.git
        
        # Add all changes
        git.add('.')
        
        # Create commit with timestamp
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        commit_message = f"Update data after flow run - {timestamp}"
        git.commit('-m', commit_message)
        
        # Push changes
        git.push('origin', 'main')
        print("Successfully pushed changes to repository")
    except Exception as e:
        print(f"Error during Git operations: {e}")

@flow(name="LinkedIn Welcome Bot", log_prints=True)
def main_flow():
    driver, wait = initialize_driver()
    try:
        driver.get("https://www.skool.com/ai-automations-by-jack-4235?c=d808479cda0c4b7da4c75660452eed76&s=newest-cm&fl=")
        time.sleep(10)
        post_details = collect_posts(driver, wait)
        comment_on_posts(driver, wait, post_details)
    
    finally:
        print("Closing browser")
        driver.quit()
        # Add Git operations after flow completion
        git_operations()


if __name__ == "__main__":
    main_flow()
    
        
# %%

